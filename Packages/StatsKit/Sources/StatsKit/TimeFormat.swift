/// Formats solve times the way cubers read them: `9.87`, `1:02.34`. Truncates to centiseconds, as the WCA does.
public enum TimeFormat {
    public static func string(ms: Int) -> String {
        let cs = ms / 10
        let minutes = cs / 6000
        let seconds = cs / 100 % 60
        let fraction = cs % 100
        let fractionText = fraction < 10 ? "0\(fraction)" : "\(fraction)"
        if minutes > 0 {
            let secondsText = seconds < 10 ? "0\(seconds)" : "\(seconds)"
            return "\(minutes):\(secondsText).\(fractionText)"
        }
        return "\(seconds).\(fractionText)"
    }
}

extension SolveResult {
    /// `12.34`, `14.34+` for +2 (penalty included), or `DNF`.
    public var formatted: String {
        switch penalty {
        case .none: TimeFormat.string(ms: timeMs)
        case .plusTwo: TimeFormat.string(ms: timeMs + 2000) + "+"
        case .dnf: "DNF"
        }
    }
}
