import AppKit
import CoreMedia
import CoreVideo
import Foundation
import Network
import ScreenCaptureKit
import SeleneCore

/// Watches for the target monitor, keeps one `SCStream` on it and streams edge colours to WLED.
///
/// Display supervision and WLED power run on the main thread. Frames, colours and UDP run on
/// `frameQueue`.
final class Engine: NSObject, SCStreamOutput, SCStreamDelegate {
    // Utility QoS lets the scheduler keep frame work on the efficiency cores. A frame is 3,000
    // pixels of averaging, so the extra latency is well below one frame interval.
    private let frameQueue = DispatchQueue(label: "selene.frames", qos: .utility)
    private let udp: NWConnection
    private var keepaliveTimer: DispatchSourceTimer?

    // Main thread.
    private var stream: SCStream?
    private var starting = false
    private var targetID: CGDirectDisplayID?
    private var targetAsleep = false
    private var wledOn: Bool?
    private var wledConfirmed: Bool?
    private var lastWledPush = Date.distantPast
    private var wledError: String?
    private var wledRequest = 0
    private var release = 0
    /// The local address of the UDP connection, which WLED reports as `lip` while it streams from us.
    private(set) var localIP: String?
    private var captureSize: (width: Int, height: Int)?
    private(set) var enabled = true
    private var fpsWindowStart = Date()
    private var framesInWindow = 0
    /// Frames per second over the last supervision tick; nil without a running capture.
    private(set) var measuredFPS: Double?
    private(set) var board = BoardStatus.unknown
    private var boardPolling = false
    private var lastBoardPoll = Date.distantPast

    /// Called on the main thread after each supervision tick and after `setEnabled`.
    var onChange: (() -> Void)?

    // Frame queue.
    private var colors = [Double](repeating: 0, count: Config.ledCount * 3)
    private var haveColors = false
    private var zones: [Zone] = []
    private var zonesW = 0, zonesH = 0
    private var lastFrame = Date.distantPast
    private var lastSend = Date.distantPast
    private var lastPacket = Data()
    private var paused = true

    override init() {
        udp = NWConnection(host: NWEndpoint.Host(Config.wledHost),
                           port: NWEndpoint.Port(rawValue: Config.wledUDPPort)!, using: .udp)
        super.init()
        // A launchd process without Local Network permission fails its sends silently;
        // this state line is the only trace of it.
        udp.stateUpdateHandler = { state in log("udp: \(state)", dedupe: true) }
        udp.pathUpdateHandler = { [weak self] path in
            var ip: String?
            if case .hostPort(let host, _)? = path.localEndpoint { ip = "\(host)" }
            DispatchQueue.main.async { self?.localIP = ip }
        }
        udp.start(queue: frameQueue)
    }

    func run() {
        if !CGPreflightScreenCaptureAccess() {
            log("no Screen Recording permission yet -> requesting")
            CGRequestScreenCaptureAccess()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.tick() }
        // `.common` keeps supervision running while the menu bar menu is open.
        let supervision = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        supervision.tolerance = 0.5
        RunLoop.main.add(supervision, forMode: .common)
        let t = DispatchSource.makeTimerSource(queue: frameQueue)
        t.schedule(deadline: .now() + 0.5, repeating: 0.5, leeway: .milliseconds(100))
        t.setEventHandler { [weak self] in self?.keepalive() }
        t.resume()
        keepaliveTimer = t
        log("selene started: monitor '\(Config.monitorName)', WLED \(Config.wledHost), \(Config.ledCount) LEDs, "
            + "\(Config.fps) fps, width \(Config.captureWidth), nominal \(Config.nominalResolution)")
        tick()
    }

    /// Starts or stops streaming. Stopped, Selene releases the capture and turns WLED off.
    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        log(on ? "streaming started from the menu" : "streaming stopped from the menu")
        lastWledPush = .distantPast
        tick()
    }

    /// Stops streaming, turns WLED off and calls `done` once the board answers or the request
    /// times out. Without the wait, WLED falls back to its own state, which Selene left on.
    func shutdown(then done: @escaping () -> Void) {
        enabled = false
        stopStream()
        frameQueue.async { self.paused = true }
        releaseWLED(after: 0, completion: done)
        onChange?()
    }

    /// A few lines on the current state, for the menu bar tooltip. Main thread.
    var statusSummary: String {
        let monitor: String
        if targetID == nil { monitor = "not connected" } else if targetAsleep { monitor = "asleep" } else { monitor = "awake" }
        let capture: String
        if let size = captureSize, stream != nil {
            capture = "\(size.width)x\(size.height)"
        } else {
            capture = starting ? "starting" : "off"
        }
        let wled: String
        if let error = wledError { wled = "unreachable (\(error))" } else { wled = wledConfirmed.map { $0 ? "on" : "off" } ?? "unknown" }
        return ["Selene: \(enabled ? "running" : "stopped")",
                "Monitor \(Config.monitorName): \(monitor)",
                "Capture: \(capture)",
                "WLED \(Config.wledHost): \(wled)",
                "\(Config.ledCount) LEDs"].joined(separator: "\n")
    }

    // MARK: Display supervision

    private func findTarget() -> CGDirectDisplayID? {
        for s in NSScreen.screens where s.localizedName.localizedCaseInsensitiveContains(Config.monitorName) {
            if let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return CGDirectDisplayID(n.uint32Value)
            }
        }
        return nil
    }

    private func tick() {
        let id = findTarget()
        let asleep = id.map { CGDisplayIsAsleep($0) != 0 } ?? false

        if id != targetID {
            log(id.map { "monitor connected (display \($0))" } ?? "monitor disconnected")
            stopStream()
            targetID = id
            targetAsleep = false
            lastWledPush = .distantPast
        }
        if id != nil, asleep != targetAsleep {
            log(asleep ? "monitor asleep" : "monitor awake")
            targetAsleep = asleep
        }
        // A stream on a sleeping monitor still costs GPU time for frames nobody sees.
        if asleep || !enabled { stopStream() }
        let paused = !enabled || id == nil || asleep
        frameQueue.async { self.paused = paused }

        // Only the computer with the monitor owns WLED power. Without it, a client releases WLED
        // once and stays silent, so it never darkens a strip another computer streams to.
        if enabled && id != nil {
            if wledOn != true || Date().timeIntervalSince(lastWledPush) > Config.wledStateRefresh {
                setWLED(on: true)
            }
        } else if wledOn != false {
            releaseWLED(after: Config.releaseDelay)
        }
        if enabled, let id = id, !asleep, stream == nil, !starting { startStream(displayID: id) }

        let now = Date()
        let elapsed = now.timeIntervalSince(fpsWindowStart)
        measuredFPS = stream != nil && !starting && elapsed > 0 ? Double(framesInWindow) / elapsed : nil
        fpsWindowStart = now
        framesInWindow = 0
        if now.timeIntervalSince(lastBoardPoll) > Config.boardPollInterval { pollBoard() }
        onChange?()
    }

    private func startStream(displayID: CGDirectDisplayID) {
        starting = true
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            DispatchQueue.main.async {
                guard self.enabled, self.targetID == displayID, !self.targetAsleep else { self.starting = false; return }
                guard let display = content?.displays.first(where: { $0.displayID == displayID }) else {
                    log("capture unavailable: \(error?.localizedDescription ?? "display not shareable")", dedupe: true)
                    self.starting = false
                    return
                }
                let cfg = SCStreamConfiguration()
                cfg.width = Config.captureWidth
                cfg.height = max(2, Int((Double(Config.captureWidth) * Double(display.height) / Double(display.width)).rounded()))
                cfg.minimumFrameInterval = CMTime(value: 1, timescale: Config.fps)
                // The LG runs at 1920x1080 points on 3840x2160 pixels. Scaling from points reads
                // a quarter of the pixels on the GPU, and 128 output columns lose nothing by it.
                if Config.nominalResolution { cfg.captureResolution = .nominal }
                cfg.pixelFormat = kCVPixelFormatType_32BGRA
                cfg.showsCursor = false
                cfg.queueDepth = 3
                let s = SCStream(filter: SCContentFilter(display: display, excludingWindows: []),
                                 configuration: cfg, delegate: self)
                do {
                    try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.frameQueue)
                } catch {
                    log("addStreamOutput failed: \(error.localizedDescription)", dedupe: true)
                    self.starting = false
                    return
                }
                self.stream = s
                s.startCapture { error in
                    DispatchQueue.main.async {
                        self.starting = false
                        // A stop or a monitor change while the start was pending leaves `s`
                        // unowned. Left running, it is a second capture session.
                        if self.stream !== s || !self.enabled || self.targetAsleep {
                            if error == nil { s.stopCapture { _ in } }
                            if self.stream === s { self.stream = nil }
                            return
                        }
                        if let error = error {
                            log("startCapture failed: \(error.localizedDescription)", dedupe: true)
                            if self.stream === s { self.stream = nil }
                        } else {
                            self.captureSize = (cfg.width, cfg.height)
                            self.fpsWindowStart = Date()
                            self.framesInWindow = 0
                            log("capture started \(cfg.width)x\(cfg.height) @ \(Config.fps) fps")
                        }
                    }
                }
            }
        }
    }

    private func stopStream() {
        if let s = stream { s.stopCapture { _ in } }
        stream = nil
        frameQueue.async { self.haveColors = false }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            log("capture stopped: \(error.localizedDescription)")
            if self.stream === stream { self.stream = nil }
        }
    }

    // MARK: WLED power

    private func setWLED(on: Bool, completion: (() -> Void)? = nil) {
        wledOn = on
        lastWledPush = Date()
        wledRequest += 1
        let request = wledRequest
        var req = URLRequest(url: URL(string: "http://\(Config.wledHost)/json/state")!, timeoutInterval: 4)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = on ? #"{"on":true,"bri":255}"#.data(using: .utf8) : #"{"on":false}"#.data(using: .utf8)
        URLSession.shared.dataTask(with: req) { _, resp, error in
            DispatchQueue.main.async {
                defer { completion?() }
                // A quick Stop and Start sends two requests, and the board may finish them in
                // either order. Only the newest one tells the state that `wledOn` asked for.
                guard request == self.wledRequest else { return }
                if let error = error {
                    log("WLED unreachable: \(error.localizedDescription)", dedupe: true)
                    self.wledError = error.localizedDescription
                    self.wledOn = nil          // retry on the next tick
                    self.wledConfirmed = nil
                } else if (resp as? HTTPURLResponse)?.statusCode != 200 {
                    log("WLED HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)", dedupe: true)
                    self.wledError = "HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)"
                    self.wledOn = nil
                    self.wledConfirmed = nil
                } else if self.wledConfirmed != on {
                    self.wledError = nil
                    log("WLED \(on ? "on" : "off")")
                    self.wledConfirmed = on
                }
            }
        }.resume()
    }

    /// Switches WLED off unless another computer streams to it. `after` gives the computer that
    /// gains the monitor time to start its stream. A newer power change cancels the release.
    private func releaseWLED(after delay: TimeInterval, completion: (() -> Void)? = nil) {
        wledOn = false
        release += 1
        let id = release
        let current = { id == self.release && self.wledOn == false }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard current() else { completion?(); return }
            self.fetchBoard { status in
                guard current() else { completion?(); return }
                // Without a known local address, `lip` may be this computer's own, so switch off.
                if case let .online(live, liveIP, _, _, _, _) = status, live, !liveIP.isEmpty,
                   let me = self.localIP, liveIP != me {
                    log("WLED left on: \(liveIP) streams to it", dedupe: true)
                    self.wledConfirmed = nil
                    completion?()
                } else {
                    self.setWLED(on: false, completion: completion)
                }
            }
        }
    }

    // MARK: Board status

    /// Reads `/json/si` from the board for the menu, and switches WLED back on when this computer
    /// has the monitor and finds it off. Main thread.
    func pollBoard() {
        guard !boardPolling else { return }
        boardPolling = true
        lastBoardPoll = Date()
        fetchBoard { status in
            self.boardPolling = false
            self.board = status
            // Another computer's release can land after this computer's `on`.
            if case let .online(_, _, on, _, _, _) = status, !on, self.wledOn == true {
                log("WLED found off -> on")
                self.setWLED(on: true)
            }
            self.onChange?()
        }
    }

    /// Reads state and info from the board and calls `completion` on the main thread.
    private func fetchBoard(_ completion: @escaping (BoardStatus) -> Void) {
        let url = URL(string: "http://\(Config.wledHost)/json/si")!
        // WLED sends no cache headers, so the default policy may hand back an old response.
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3)
        URLSession.shared.dataTask(with: req) { data, _, error in
            let status: BoardStatus
            if let data = data, let si = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let info = si["info"] as? [String: Any], let state = si["state"] as? [String: Any] {
                let wifi = info["wifi"] as? [String: Any]
                status = .online(live: info["live"] as? Bool ?? false,
                                 liveIP: info["lip"] as? String ?? "",
                                 on: state["on"] as? Bool ?? false,
                                 signal: wifi?["signal"] as? Int,
                                 uptime: info["uptime"] as? Int,
                                 version: info["ver"] as? String ?? "?")
            } else {
                status = .unreachable(error?.localizedDescription ?? "no valid /json/si")
            }
            DispatchQueue.main.async { completion(status) }
        }.resume()
    }

    // MARK: Frames

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, !paused, sb.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pb = CMSampleBufferGetImageBuffer(sb) else { return }

        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb)?.assumingMemoryBound(to: UInt8.self) else { return }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), bpr = CVPixelBufferGetBytesPerRow(pb)
        if w != zonesW || h != zonesH { zones = buildZones(width: w, height: h); zonesW = w; zonesH = h }

        let now = Date()
        let a = haveColors ? smoothingFactor(interval: now.timeIntervalSince(lastFrame), timeConstant: Config.smoothingTime) : 1.0
        lastFrame = now
        for (i, z) in zones.enumerated() {
            let (r, g, b) = average(base, bytesPerRow: bpr, zone: z)
            colors[i * 3]     += a * (r - colors[i * 3])
            colors[i * 3 + 1] += a * (g - colors[i * 3 + 1])
            colors[i * 3 + 2] += a * (b - colors[i * 3 + 2])
        }
        haveColors = true
        DispatchQueue.main.async { self.framesInWindow += 1 }
        send(force: false)
    }

    // SCK delivers no frames for a static screen, and WLED leaves realtime mode after
    // `wledTimeout`. Resending the last colours keeps the strip on the stream.
    private func keepalive() {
        if !paused, haveColors, Date().timeIntervalSince(lastSend) >= Config.keepalive { send(force: true) }
    }

    /// Sends the current colours. Without `force`, a packet equal to the last one stays unsent:
    /// the smoothing settles to identical bytes within a few frames, and the keepalive covers WLED.
    private func send(force: Bool) {
        let pkt = drgbPacket(colors, gamma: Config.gamma, timeout: Config.wledTimeout)
        if !force && pkt == lastPacket { return }
        udp.send(content: pkt, completion: .contentProcessed { _ in })
        lastPacket = pkt
        lastSend = Date()
    }
}

enum BoardStatus {
    case unknown
    case unreachable(String)
    case online(live: Bool, liveIP: String, on: Bool, signal: Int?, uptime: Int?, version: String)
}
