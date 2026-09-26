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

    /// Parses WCA notation such as `R`, `U'` or `F2`.
    public init?(notation: some StringProtocol) {
        guard let first = notation.first, let face = Face(rawValue: String(first)) else { return nil }
        switch notation.dropFirst() {
        case "": self.init(face, 1)
        case "2": self.init(face, 2)
        case "'": self.init(face, 3)
        default: return nil
        }
    }

    /// Solver move index: `face * 3 + (turns - 1)` with faces in U R F D L B order.
    init(index: Int) {
        self.init(Face.allCases[index / 3], index % 3 + 1)
    }

    var index: Int {
        Face.allCases.firstIndex(of: face)! * 3 + turns - 1
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

    /// Parses space-separated WCA notation, e.g. `R U' F2`.
    public init?(parsing notation: String) {
        var moves: [Move] = []
        for token in notation.split(separator: " ") {
            guard let move = Move(notation: token) else { return nil }
            moves.append(move)
        }
        self.init(moves)
    }

    public var description: String {
        moves.map(\.description).joined(separator: " ")
    }
}
