/// A pixel rectangle of the captured frame, half-open on both axes.
public struct Zone: Equatable {
    public let x0, x1, y0, y1: Int
}

/// Returns one zone per LED, in strip order, for a frame of `width` x `height` pixels.
public func buildZones(width w: Int, height h: Int) -> [Zone] {
    let dh = Config.depthTopBottom, dv = Config.depthSides
    var z: [Zone] = []
    func add(_ fx0: Double, _ fx1: Double, _ fy0: Double, _ fy1: Double) {
        let x0 = min(max(Int((fx0 * Double(w)).rounded(.down)), 0), w - 1)
        let x1 = min(max(Int((fx1 * Double(w)).rounded(.up)), x0 + 1), w)
        let y0 = min(max(Int((fy0 * Double(h)).rounded(.down)), 0), h - 1)
        let y1 = min(max(Int((fy1 * Double(h)).rounded(.up)), y0 + 1), h)
        z.append(Zone(x0: x0, x1: x1, y0: y0, y1: y1))
    }
    let L = Double(Config.left), T = Double(Config.top), R = Double(Config.right), B = Double(Config.bottom)
    for i in 0..<Config.left { add(0, dv, 1 - Double(i + 1) / L, 1 - Double(i) / L) }        // bottom to top
    for j in 0..<Config.top { add(Double(j) / T, Double(j + 1) / T, 0, dh) }                  // left to right
    for k in 0..<Config.right { add(1 - dv, 1, Double(k) / R, Double(k + 1) / R) }            // top to bottom
    for m in 0..<Config.bottom { add(1 - Double(m + 1) / B, 1 - Double(m) / B, 1 - dh, 1) }   // right to left
    return z
}

/// Averages a BGRA frame over `zone` and returns red, green and blue in 0...255.
public func average(_ base: UnsafePointer<UInt8>, bytesPerRow bpr: Int, zone z: Zone) -> (Double, Double, Double) {
    var sr = 0, sg = 0, sb = 0
    for y in z.y0..<z.y1 {
        var p = base + y * bpr + z.x0 * 4
        for _ in z.x0..<z.x1 {
            sb += Int(p[0]); sg += Int(p[1]); sr += Int(p[2])
            p += 4
        }
    }
    let n = Double((z.x1 - z.x0) * (z.y1 - z.y0))
    return (Double(sr) / n, Double(sg) / n, Double(sb) / n)
}
