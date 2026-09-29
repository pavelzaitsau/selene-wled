# Migration from HyperHDR

Status on 2026-09-29: **steps 1 and 2 are done.** The prototype from branch `feat/macos-client`
drives the strip, and the watcher and HyperHDR are stopped. HyperHDR stays installed until the
prototype passes every requirement in step 3.

Delete this file and `legacy/` in the commit that removes HyperHDR.

## The HyperHDR setup

| Piece | Where |
| --- | --- |
| HyperHDR 22.0.0 | `/Applications/hyperhdr.app`, settings in `~/Library/Preferences/HyperHDR/db/hyperhdr.db` |
| Watcher | LaunchAgent `com.pavel.ambilight-watch`, runs `~/Library/Application Support/ambilight/watch.py` |
| Watcher log | `~/Library/Application Support/ambilight/watch.log` |
| Database backup | `~/Library/Application Support/ambilight/backup/hyperhdr.db.2026-09-29-final` |

The watcher starts HyperHDR, keeps its grabber on the LG and switches WLED off when the LG is gone.
The repository keeps [a copy of the watcher](../legacy/hyperhdr-watch.py).

HyperHDR holds 104 LEDs in the order from [hardware.md](hardware.md#led-order). Its system grabber
runs on `Display id: 4` at 15 fps and width 256. `localApiAuth` is on; the Flatbuffers server and
the camera grabber are off.

## Switch steps

1. Install the macOS client as its README describes, and grant the permissions it asks for.
2. Stop the old pair, so that two hosts do not stream at once:

   ```bash
   launchctl bootout gui/$(id -u)/com.pavel.ambilight-watch
   pkill -TERM -f /Applications/hyperhdr.app/Contents/MacOS/hyperhdr
   ```

3. Walk through every "Verified by" line in [requirements.md](requirements.md). Pavel confirms
   R1 by looking at the strip.
4. Only then remove HyperHDR:

   ```bash
   rm ~/Library/LaunchAgents/com.pavel.ambilight-watch.plist
   rm -rf ~/Library/Application\ Support/ambilight
   rm -rf /Applications/hyperhdr.app ~/Library/Preferences/HyperHDR
   tccutil reset ScreenCapture com.awawa-dev.hyperhdr
   security delete-generic-password -s ambilight -a hyperhdr-admin
   security delete-generic-password -s ambilight -a hyperhdr-token
   ```

   The copy of the test pattern under Application Support goes with that folder.
   [tools/test-pattern.html](../tools/test-pattern.html) stays.

To roll back before step 4, stop the new client and start the watcher again:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pavel.ambilight-watch.plist
```
