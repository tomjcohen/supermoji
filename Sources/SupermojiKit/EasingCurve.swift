/// Easing curve applied to the cross-fade blend parameter `t` (0...1).
///
/// These shape the *blend amount* over a fade, not the frame timing — frames
/// are evenly spaced in time, so e.g. `easeInOut` makes the fade linger on each
/// emoji and move briskly through the middle.
public enum EasingCurve: String, Sendable, CaseIterable {
    case linear
    case easeIn = "ease-in"
    case easeOut = "ease-out"
    case easeInOut = "ease-in-out"

    /// Maps a linear progress value in 0...1 to an eased value in 0...1.
    public func apply(_ t: Double) -> Double {
        switch self {
        case .linear: t
        case .easeIn: t * t
        case .easeOut: 1 - (1 - t) * (1 - t)
        case .easeInOut: 3 * t * t - 2 * t * t * t
        }
    }
}
