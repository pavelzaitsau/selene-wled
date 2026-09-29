import Foundation

/// Encodes a WLED realtime packet, protocol 2 (DRGB): protocol byte, timeout byte, RGB triplets.
///
/// `colors` holds red, green and blue per LED in 0...255; values outside are clamped.
/// `timeout` is in seconds. WLED accepts up to 490 LEDs in one packet.
public func drgbPacket(_ colors: [Double], gamma: Double, timeout: UInt8) -> Data {
    var pkt = Data(capacity: 2 + colors.count)
    pkt.append(2)
    pkt.append(timeout)
    for c in colors {
        let v = pow(max(0, min(255, c)) / 255, gamma) * 255
        pkt.append(UInt8(v.rounded()))
    }
    return pkt
}
