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
        udp.start(queue: frameQueue)
    }

    func run() {
        if !CGPreflightScreenCaptureAccess() {
            log("no Screen Recording permission yet -> requesting")
            CGRequestScreenCaptureAccess()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.tick() }
        let supervision = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        supervision.tolerance = 0.5
        let t = DispatchSource.makeTimerSource(queue: frameQueue)
        t.schedule(deadline: .now() + 0.5, repeating: 0.5, leeway: .milliseconds(100))
        t.setEventHandler { [weak self] in self?.keepalive() }
        t.resume()
        keepaliveTimer = t
        log("selene started: monitor '\(Config.monitorName)', WLED \(Config.wledHost), \(Config.ledCount) LEDs, "
            + "\(Config.fps) fps, width \(Config.captureWidth), nominal \(Config.nominalResolution)")
        tick()
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
        if asleep { stopStream() }
        frameQueue.async { self.paused = (id == nil) || asleep }

        let wantOn = id != nil
        if wledOn != wantOn || Date().timeIntervalSince(lastWledPush) > Config.wledStateRefresh {
            setWLED(on: wantOn)
        }
        if let id = id, !asleep, stream == nil, !starting { startStream(displayID: id) }
    }

    private func startStream(displayID: CGDirectDisplayID) {
        starting = true
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            DispatchQueue.main.async {
                guard self.targetID == displayID, !self.targetAsleep else { self.starting = false; return }
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
                        if let error = error {
                            log("startCapture failed: \(error.localizedDescription)", dedupe: true)
                            if self.stream === s { self.stream = nil }
                        } else {
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

    private func setWLED(on: Bool) {
        wledOn = on
        lastWledPush = Date()
        var req = URLRequest(url: URL(string: "http://\(Config.wledHost)/json/state")!, timeoutInterval: 4)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = on ? #"{"on":true,"bri":255}"#.data(using: .utf8) : #"{"on":false}"#.data(using: .utf8)
        URLSession.shared.dataTask(with: req) { _, resp, error in
            DispatchQueue.main.async {
                if let error = error {
                    log("WLED unreachable: \(error.localizedDescription)", dedupe: true)
                    self.wledOn = nil          // retry on the next tick
                    self.wledConfirmed = nil
                } else if (resp as? HTTPURLResponse)?.statusCode != 200 {
                    log("WLED HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)", dedupe: true)
                    self.wledOn = nil
                    self.wledConfirmed = nil
                } else if self.wledConfirmed != on {
                    log("WLED \(on ? "on" : "off")")
                    self.wledConfirmed = on
                }
            }
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
