import Foundation

public enum Config {
    public static let monitorName = "LG ULTRAFINE"
    public static let wledHost = "192.168.1.35"
    public static let wledUDPPort: UInt16 = 21324
    public static let wledTimeout: UInt8 = 2              // s; WLED leaves realtime mode after this
    // LED 0 is bottom-left; the strip runs clockwise as seen from the front.
    public static let left = 18, top = 34, right = 18, bottom = 34
    public static let depthTopBottom = 0.08               // zone depth, fraction of height
    public static let depthSides = 0.05                   // zone depth, fraction of width
    public static let gamma = 1.5
    public static let keepalive = 1.0                     // s; resend on a static screen
    public static let wledStateRefresh = 60.0             // s; re-assert WLED on/off
    public static var ledCount: Int { left + top + right + bottom }

    // Tunable without a rebuild, which would cost the Screen Recording grant:
    //     defaults write com.pavel.selene fps -int 20
    // then restart the LaunchAgent. `defaults delete com.pavel.selene` restores the defaults.
    // The standard domain of Selene.app is its bundle id. A suite named after the bundle id
    // returns nil, so the knobs read the standard domain.
    private static func tuned<T>(_ key: String, _ fallback: T) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? fallback
    }

    /// Upper bound of the capture rate. ScreenCaptureKit sends no frame while the picture is still.
    public static let fps: Int32 = Int32(tuned("fps", 15))
    /// Width of the frame ScreenCaptureKit scales to on the GPU; the height follows the aspect.
    public static let captureWidth: Int = tuned("captureWidth", 128)
    /// Scale from the display's points (1920 wide on the LG) instead of its pixels (3840).
    public static let nominalResolution: Bool = tuned("nominalResolution", true)
    /// Time constant of the colour smoothing, s. 0.0935 s equals an EMA factor of 0.30 at 30 fps.
    public static let smoothingTime: Double = tuned("smoothingTime", 0.0935)
}

/// Returns the EMA factor for a frame that arrives `interval` seconds after the previous one.
///
/// A factor tied to time rather than to frames keeps the look of the smoothing when the frame rate
/// changes. A zero `timeConstant` turns smoothing off and returns 1.
public func smoothingFactor(interval: Double, timeConstant: Double) -> Double {
    timeConstant <= 0 ? 1 : 1 - exp(-max(0, interval) / timeConstant)
}
