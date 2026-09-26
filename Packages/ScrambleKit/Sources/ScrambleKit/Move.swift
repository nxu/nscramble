/// A single outer-layer face turn in WCA notation.
public struct Move: Hashable, Sendable, CustomStringConvertible {
    public enum Face: String, CaseIterable, Sendable {
        case U, R, F, D, L, B
    }

    /// Quarter turns clockwise: 1, 2 or 3 (3 == counter-clockwise).
    public let face: Face
    public let turns: Int

    public init(_ face: Face, _ turns: Int = 1) {
        precondition((1...3).contains(turns), "turns must be 1, 2 or 3")
        self.face = face
        self.turns = turns
    }

    public var description: String {
        switch turns {
        case 1: face.rawValue
        case 2: face.rawValue + "2"
        default: face.rawValue + "'"
        }
    }
}

/// A scramble sequence.
public struct Scramble: Hashable, Sendable, CustomStringConvertible {
    public let moves: [Move]

    public init(_ moves: [Move]) {
        self.moves = moves
    }

    public var description: String {
        moves.map(\.description).joined(separator: " ")
    }
}
