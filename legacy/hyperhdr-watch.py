#!/usr/bin/python3
"""Ambilight watcher (LG ULTRAFINE + HyperHDR + WLED).

Runs as LaunchAgent com.pavel.ambilight-watch, stdlib only (system /usr/bin/python3).
Every POLL seconds it *reconciles* the desired state instead of reacting to events:
  * HyperHDR not running           -> start it
  * LG connected                   -> system grabber on the LG display, LED output on, WLED on
  * LG not connected               -> system grabber + LED output off, WLED off
Secrets are read from the macOS Keychain (service "ambilight").
"""
import json, os, sqlite3, subprocess, time, urllib.request

MONITOR = "LG ULTRAFINE"
WLED = "http://192.168.1.35"
HH_RPC = "http://127.0.0.1:8090/json-rpc"
HH_APP = "/Applications/hyperhdr.app"
HH_BIN = HH_APP + "/Contents/MacOS/hyperhdr"
POLL = 5            # seconds between checks
WLED_CHECK = 60     # seconds between WLED on/off verification
FIX_BACKOFF = 30    # seconds to wait after a grabber restart before trying again
HUNG_ERRORS = 6     # consecutive API failures (~1 min) while the process exists -> force restart
HH_DB = os.path.expanduser("~/Library/Preferences/HyperHDR/db/hyperhdr.db")
LOG = os.path.expanduser("~/Library/Application Support/ambilight/watch.log")
LOG_MAX = 256 * 1024

JXA = ('ObjC.import("AppKit");JSON.stringify($.NSScreen.screens.js.map('
       's=>[s.localizedName.js,s.deviceDescription.objectForKey("NSScreenNumber").js]))')


def log(*a):
    try:
        if os.path.exists(LOG) and os.path.getsize(LOG) > LOG_MAX:
            open(LOG, "w").close()
    except OSError:
        pass
    print(time.strftime("%Y-%m-%d %H:%M:%S"), *a, flush=True)


def run(args, timeout=10):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout)


def secret(account):
    r = run(["/usr/bin/security", "find-generic-password", "-s", "ambilight", "-a", account, "-w"])
    if r.returncode != 0:
        raise RuntimeError("keychain item ambilight/%s not found" % account)
    return r.stdout.strip()


def lg_display():
    """CGDirectDisplayID of the LG monitor, or None if it is not connected."""
    try:
        for name, num in json.loads(run(["/usr/bin/osascript", "-l", "JavaScript", "-e", JXA]).stdout or "[]"):
            if MONITOR.lower() in name.lower():
                return int(num)
    except Exception as e:
        log("screens:", e)
    return None


# ---- WLED (via /usr/bin/curl: a launchd-started python is blocked by macOS Local Network privacy)
def wled(state=None):
    args = ["/usr/bin/curl", "-s", "-m", "4"]
    if state is not None:
        args += ["-X", "POST", "-H", "Content-Type: application/json", "-d", json.dumps(state)]
    try:
        return json.loads(run(args + [WLED + "/json/state"]).stdout or "null")
    except Exception:
        return None


# ---- HyperHDR JSON-RPC (loopback, token auth)
class HyperHDR:
    def __init__(self):
        self.token = None

    def rpc(self, command, **kw):
        if self.token is None:
            self.token = secret("hyperhdr-token")
        kw.update(command=command, tan=1)
        req = urllib.request.Request(HH_RPC, json.dumps(kw).encode(), {
            "Content-Type": "application/json", "Authorization": "token " + self.token})
        with urllib.request.urlopen(req, timeout=10) as r:
            res = json.loads(r.read())
        if not res.get("success", False):
            raise RuntimeError("%s: %s" % (command, res.get("error")))
        return res.get("info")

    def component(self, name, state):
        self.rpc("componentstate", componentstate={"component": name, "state": state})

    def status(self):
        info = self.rpc("serverinfo")
        comps = {c["name"]: c["enabled"] for c in info.get("components", [])}
        owner = next((p.get("owner", "") for p in info.get("priorities", [])
                      if p.get("componentId") == "SYSTEMGRABBER" and p.get("active")), "")
        return comps, owner



def hyperhdr_running():
    return run(["/usr/bin/pgrep", "-f", HH_BIN]).returncode == 0


def start_hyperhdr():
    run(["/usr/bin/open", "-g", "-a", HH_APP])
    for _ in range(30):
        time.sleep(1)
        try:
            urllib.request.urlopen("http://127.0.0.1:8090/", timeout=2).read(1)
            time.sleep(3)
            return
        except Exception:
            pass


def restart_on_display(disp):
    """HyperHDR silently switches to another display when the configured one disappears and never
    switches back. Fix: stop it gracefully, make sure the DB points at the wanted display, start it.
    The DB is only touched while HyperHDR is stopped (the JSON API needs the admin password, and a
    partial setconfig would reset instance settings)."""
    want = "Display id: %d" % disp
    run(["/usr/bin/pkill", "-TERM", "-f", HH_BIN])
    for _ in range(20):
        if not hyperhdr_running():
            break
        time.sleep(0.5)
    else:
        log("HyperHDR did not stop, skipping DB check"); return
    db = sqlite3.connect(HH_DB)
    try:
        for inst, cfg in db.execute("select hyperhdr_instance, config from settings where type='systemGrabber'").fetchall():
            j = json.loads(cfg)
            if j.get("device") != want:
                log("DB systemGrabber.device %r -> %r" % (j.get("device"), want))
                j["device"] = want
                db.execute("update settings set config=? where type='systemGrabber' and hyperhdr_instance is ?",
                           (json.dumps(j, separators=(",", ":")), inst))
        db.commit()
    finally:
        db.close()
    start_hyperhdr()


def main():
    hh = HyperHDR()
    log("watcher started")
    last_fix = 0.0
    last_wled = 0.0
    prev = "init"
    errors = 0
    while True:
        try:
            if not hyperhdr_running():
                log("HyperHDR not running -> starting")
                start_hyperhdr()
                continue

            disp = lg_display()
            if disp != prev:
                log("LG display:", disp)
                prev, last_wled = disp, 0.0
            comps, owner = hh.status()
            errors = 0
            now = time.time()

            if disp:
                want = "Display id: %d" % disp
                if not owner.endswith(want) and now - last_fix > FIX_BACKOFF:
                    log("grabber on %r, want %r -> restart HyperHDR" % (owner or "nothing", want))
                    restart_on_display(disp)
                    last_fix = time.time()
                    continue
                for c in ("SYSTEMGRABBER", "LEDDEVICE"):
                    if not comps.get(c):
                        log("enable", c); hh.component(c, True)
                if now - last_wled > WLED_CHECK:
                    st = wled()
                    if st is not None and not st.get("on"):
                        log("WLED was off -> on"); wled({"on": True, "bri": 255})
                    last_wled = now
            else:
                for c in ("LEDDEVICE", "SYSTEMGRABBER"):
                    if comps.get(c):
                        log("disable", c); hh.component(c, False)
                        time.sleep(1.5)
                if now - last_wled > WLED_CHECK:
                    st = wled()
                    if st is not None and st.get("on"):
                        log("WLED was on -> off"); wled({"on": False})
                    last_wled = now
        except Exception as e:
            errors += 1
            log("error (%d):" % errors, e)
            hh.token = None          # re-read token next time (e.g. rotated)
            if errors >= HUNG_ERRORS and hyperhdr_running():
                log("HyperHDR API unresponsive -> force restart")
                run(["/usr/bin/pkill", "-9", "-f", HH_BIN]); time.sleep(3)
                start_hyperhdr(); errors = 0
            time.sleep(POLL)
        time.sleep(POLL)


if __name__ == "__main__":
    main()
