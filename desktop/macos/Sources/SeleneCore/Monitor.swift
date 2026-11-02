import Foundation

/// Returns true when the display named `name` is the monitor with the strip.
///
/// Without a pick, any display whose name contains `Config.monitorName` matches. A pick must match
/// the whole name, so a picked "DELL U2720Q" does not take a "DELL U2720Q Pro". Both sides drop a
/// trailing " (1)": macOS adds such a number to a display's name, and the pick must survive it.
/// Two displays of one model therefore both match; R2 rules out that setup.
public func isStripMonitor(name: String, chosen: String?) -> Bool {
    guard let chosen else { return name.localizedCaseInsensitiveContains(Config.monitorName) }
    return displayBaseName(name).localizedCaseInsensitiveCompare(displayBaseName(chosen)) == .orderedSame
}

/// `name` without the " (1)" that macOS appends to tell displays of one model apart.
func displayBaseName(_ name: String) -> String {
    guard let suffix = name.range(of: #" \(\d+\)$"#, options: .regularExpression) else { return name }
    return String(name[..<suffix.lowerBound])
}
