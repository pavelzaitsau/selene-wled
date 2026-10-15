import AppKit
import ServiceManagement

// `Selene --register` and `Selene --unregister` are for tools/install.sh and tools/uninstall.sh.
// They hand the LaunchAgent inside the bundle to launchd, or take it back, and exit.
let agent = SMAppService.agent(plistName: "com.pavel.selene.plist")
switch CommandLine.arguments.dropFirst().first {
case "--register":
    do { try agent.register() } catch { print("register failed: \(error.localizedDescription)"); exit(1) }
    switch agent.status {
    case .enabled:
        print("LaunchAgent enabled")
    case .requiresApproval:
        print("LaunchAgent registered; allow Selene under Login Items to start it")
    default:
        print("LaunchAgent not running, status \(agent.status.rawValue); see Troubleshooting in the README")
        exit(1)
    }
    exit(0)
case "--unregister":
    do { try agent.unregister() } catch { print("unregister failed: \(error.localizedDescription)"); exit(1) }
    exit(0)
default:
    break
}

// launchd gives a bundled LaunchAgent no log file, so the agent opens its own.
// A failed freopen closes the stream, so the file is opened once first to prove it works.
if isatty(STDOUT_FILENO) == 0 {
    let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
    try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    let path = logs.appendingPathComponent("selene.log").path
    if let probe = fopen(path, "a") {
        fclose(probe)
        freopen(path, "a", stdout)
        freopen(path, "a", stderr)
    }
}
setvbuf(stdout, nil, _IOLBF, 0)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let engine = Engine()
engine.run()
let statusMenu = StatusMenu(engine: engine)
app.run()
