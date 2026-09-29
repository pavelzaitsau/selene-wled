import Foundation
import SeleneCore

var failures = 0
func check(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok { failures += 1; print("FAIL line \(line): \(what)") }
}

// Layout: one zone per LED, strip order starting bottom-left, all inside the frame.
let w = 128, h = 54
let zones = buildZones(width: w, height: h)
check(zones.count == Config.ledCount, "zone count \(zones.count)")
check(zones.allSatisfy { $0.x0 >= 0 && $0.x1 <= w && $0.y0 >= 0 && $0.y1 <= h && $0.x0 < $0.x1 && $0.y0 < $0.y1 },
      "zones inside frame and non-empty")
let first = zones[0], lastLeft = zones[Config.left - 1]
check(first.x0 == 0 && first.y1 == h, "LED 0 is bottom-left: \(first)")
check(lastLeft.y0 == 0, "last left LED reaches the top: \(lastLeft)")
let firstRight = zones[Config.left + Config.top]
check(firstRight.x1 == w && firstRight.y0 == 0, "first right LED is top-right: \(firstRight)")
check(zones.last!.x0 == 0 && zones.last!.y1 == h, "last LED is back at bottom-left: \(zones.last!)")

// Average of a flat BGRA frame is its colour.
var frame = [UInt8](repeating: 0, count: w * h * 4)
for p in stride(from: 0, to: frame.count, by: 4) { frame[p] = 30; frame[p + 1] = 20; frame[p + 2] = 10 }
let (r, g, b) = frame.withUnsafeBufferPointer { average($0.baseAddress!, bytesPerRow: w * 4, zone: zones[5]) }
check(r == 10 && g == 20 && b == 30, "flat frame average \(r),\(g),\(b)")

// DRGB packet: header, clamping, gamma.
let pkt = drgbPacket([0, 255, 300, -5, 127.5, 255], gamma: 1.5, timeout: 2)
check(pkt.count == 8, "packet length \(pkt.count)")
check(pkt[0] == 2 && pkt[1] == 2, "packet header \(pkt[0]) \(pkt[1])")
check(Array(pkt[2...]) == [0, 255, 255, 0, 90, 255], "packet body \(Array(pkt[2...]))")

// Smoothing tied to time: 0.0935 s is a factor of 0.30 at 30 fps, and half the frame rate
// gives a factor close to 1 - 0.7^2.
let a30 = smoothingFactor(interval: 1.0 / 30, timeConstant: 0.0935)
let a15 = smoothingFactor(interval: 1.0 / 15, timeConstant: 0.0935)
check(abs(a30 - 0.30) < 0.005, "factor at 30 fps \(a30)")
check(abs(a15 - 0.51) < 0.005, "factor at 15 fps \(a15)")
check(smoothingFactor(interval: 1, timeConstant: 0) == 1, "zero time constant turns smoothing off")

if failures > 0 { print("\(failures) check(s) failed"); exit(1) }
print("all checks passed")
