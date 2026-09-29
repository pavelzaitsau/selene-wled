import Foundation

private let logLock = NSLock()
private let logFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f
}()
private var lastLogged = ""

/// Prints a timestamped line to stdout, which launchd sends to ~/Library/Logs/selene.log.
/// With `dedupe`, a line equal to the previous one is dropped. Safe from any queue.
func log(_ msg: String, dedupe: Bool = false) {
    logLock.lock(); defer { logLock.unlock() }
    if dedupe && msg == lastLogged { return }
    lastLogged = msg
    print("\(logFormatter.string(from: Date())) \(msg)")
}
