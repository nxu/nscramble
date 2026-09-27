/// A computed statistic.
public enum Stat: Equatable, Sendable {
    case time(ms: Int)
    case dnf
    /// Not enough solves.
    case none

    /// `12.34`, `DNF` or `–`.
    public var formatted: String {
        switch self {
        case .time(let ms): TimeFormat.string(ms: ms)
        case .dnf: "DNF"
        case .none: "–"
        }
    }
}

public enum Statistics {
    /// Trimmed average, csTimer/WCA style: drop `ceil(5%)` (at least 1) of the results from each end,
    /// then take the mean of the rest. DNFs count as the slowest results; if any DNF survives the
    /// trim, the average is DNF. Needs at least 3 results. Rounded to centiseconds.
    public static func average(_ results: [SolveResult]) -> Stat {
        let n = results.count
        guard n >= 3 else { return .none }
        let trim = max(1, (n * 5 + 99) / 100)
        let sorted = results.map { $0.effectiveMs ?? Int.max }.sorted()
        let kept = sorted[trim..<(n - trim)]
        guard !kept.contains(Int.max) else { return .dnf }
        return .time(ms: roundedToCentiseconds(Double(kept.reduce(0, +)) / Double(kept.count)))
    }

    /// Average of the `count` most recent results (`newestFirst[0..<count]`), e.g. ao5.
    public static func averageOf(_ count: Int, _ newestFirst: [SolveResult]) -> Stat {
        guard newestFirst.count >= count else { return .none }
        return average(Array(newestFirst.prefix(count)))
    }

    static func roundedToCentiseconds(_ ms: Double) -> Int {
        Int((ms / 10).rounded()) * 10
    }
}

/// Everything the stats panel shows.
public struct StatsSummary: Equatable, Sendable {
    /// Averages of all solves in each period.
    public let today: Stat
    public let last7Days: Stat
    public let last30Days: Stat
    public let ao5: Stat
    public let ao12: Stat
    public let ao100: Stat

    /// - Parameters:
    ///   - dated: solves of (at least) the last 30 days with their `YYYY-MM-DD` day.
    ///   - newestFirst: the most recent solves (at least 100 if available), newest first.
    ///   - today, weekStart, monthStart: `YYYY-MM-DD` days; periods include days >= their start.
    public init(
        dated: [(day: String, result: SolveResult)],
        newestFirst: [SolveResult],
        today: String,
        weekStart: String,
        monthStart: String
    ) {
        func results(from start: String) -> [SolveResult] {
            dated.filter { $0.day >= start }.map(\.result)
        }
        self.today = Statistics.average(results(from: today))
        last7Days = Statistics.average(results(from: weekStart))
        last30Days = Statistics.average(results(from: monthStart))
        ao5 = Statistics.averageOf(5, newestFirst)
        ao12 = Statistics.averageOf(12, newestFirst)
        ao100 = Statistics.averageOf(100, newestFirst)
    }
}
