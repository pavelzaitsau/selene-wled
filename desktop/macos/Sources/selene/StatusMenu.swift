import AppKit
import SeleneCore

/// The menu bar item: a moon icon, the engine state in its tooltip, the current fps and board
/// status, Start/Stop and Quit.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let engine: Engine
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let fpsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let boardItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    // Wi-Fi, uptime and WLED version, indented under the board line; hidden without data.
    private let boardDetailItems = (0..<3).map { _ in NSMenuItem(title: "", action: nil, keyEquivalent: "") }
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    private var openTimer: Timer?
    private let runningImage = StatusMenu.moon("moon.fill")
    private let stoppedImage = StatusMenu.moon("moon")

    init(engine: Engine) {
        self.engine = engine
        super.init()
        fpsItem.isEnabled = false
        boardItem.isEnabled = false
        for detail in boardDetailItems {
            detail.isEnabled = false
            detail.indentationLevel = 1
        }
        toggleItem.target = self
        let quit = NSMenuItem(title: "Quit Selene", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(fpsItem)
        menu.addItem(boardItem)
        boardDetailItems.forEach(menu.addItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(quit)
        item.menu = menu
        engine.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func refresh() {
        let running = engine.enabled
        toggleItem.title = running ? "Stop" : "Start"
        fpsItem.title = fpsText
        let board = boardLines
        boardItem.title = board.first ?? ""
        for (i, detail) in boardDetailItems.enumerated() {
            let line = i + 1 < board.count ? board[i + 1] : nil
            detail.title = line ?? ""
            detail.isHidden = line == nil
        }
        if let button = item.button {
            let image = running ? runningImage : stoppedImage
            if button.image !== image { button.image = image }
            button.toolTip = ([engine.statusSummary, fpsText] + board).joined(separator: "\n")
        }
    }

    private static func moon(_ symbol: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Selene")
        image?.isTemplate = true
        return image
    }

    private var fpsText: String {
        guard let fps = engine.measuredFPS else { return "FPS: –" }
        // ScreenCaptureKit sends no frame while the picture is still; the keepalive holds the strip.
        if fps < 0.05 { return "FPS: 0, still picture" }
        return String(format: "FPS: %.1f of %d", fps, Config.fps)
    }

    /// The board state first, then one line per detail.
    private var boardLines: [String] {
        switch engine.board {
        case .unknown:
            return ["Board: checking"]
        case .unreachable:
            return ["Board: unreachable"]
        case let .online(live, liveIP, signal, uptime, version):
            var lines: [String]
            if !live {
                lines = ["Board: online, not live"]
            } else if liveIP == engine.localIP {
                lines = ["Board: live from this Mac"]
            } else {
                lines = ["Board: live from \(liveIP)"]
            }
            if let signal = signal { lines.append("Wi-Fi: \(signal)%") }
            if let uptime = uptime { lines.append("Uptime: \(Self.duration(uptime))") }
            lines.append("WLED: \(version)")
            return lines
        }
    }

    private static func duration(_ seconds: Int) -> String {
        if seconds < 3600 { return "\(seconds / 60) min" }
        if seconds < 86400 { return "\(seconds / 3600) h \(seconds % 3600 / 60) min" }
        return "\(seconds / 86400) d \(seconds % 86400 / 3600) h"
    }

    // An open menu runs the event-tracking run loop mode, so the timer registers for `.common`.
    func menuWillOpen(_ menu: NSMenu) {
        engine.pollBoard()
        refresh()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.engine.pollBoard() }
        RunLoop.main.add(t, forMode: .common)
        openTimer = t
    }

    func menuDidClose(_ menu: NSMenu) {
        openTimer?.invalidate()
        openTimer = nil
    }

    @objc private func toggle() {
        engine.setEnabled(!engine.enabled)
    }

    // The LaunchAgent restarts Selene only after an unsuccessful exit, so a clean exit stays down.
    @objc private func quit() {
        log("quit from the menu")
        engine.shutdown { NSApp.terminate(nil) }
    }
}
