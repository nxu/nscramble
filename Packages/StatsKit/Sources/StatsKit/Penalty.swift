/// WCA penalty applied to a solve. Raw values match the `penalty` column in the database.
public enum Penalty: Int, Codable, Sendable, CaseIterable {
    case none = 0
    case plusTwo = 1
    case dnf = 2
}

/// A solve result as seen by the statistics code.
public struct SolveResult: Hashable, Sendable {
    public let timeMs: Int
    public let penalty: Penalty

    public init(timeMs: Int, penalty: Penalty = .none) {
        self.timeMs = timeMs
        self.penalty = penalty
    }

    /// Effective time in milliseconds, or `nil` for a DNF.
    public var effectiveMs: Int? {
        switch penalty {
        case .none: timeMs
        case .plusTwo: timeMs + 2000
        case .dnf: nil
        }
    }
}
