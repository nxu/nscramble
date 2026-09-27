import Foundation
@testable import ScrambleKit

/// Deterministic generator so failures are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct CubingJSCase: Decodable, Sendable, CustomTestStringConvertible {
    let scramble: String
    let facelets: String

    var testDescription: String { scramble }

    static let all: [CubingJSCase] = {
        let url = Bundle.module.url(forResource: "cubingjs", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode([CubingJSCase].self, from: Data(contentsOf: url))
    }()
}

import Testing

// MARK: Notation and cube-state helpers (tests only)

extension Move {
    /// Parses WCA notation such as `R`, `U'` or `F2`.
    init?(notation: some StringProtocol) {
        guard let first = notation.first, let face = Face(rawValue: String(first)) else { return nil }
        switch notation.dropFirst() {
        case "": self.init(face, 1)
        case "2": self.init(face, 2)
        case "'": self.init(face, 3)
        default: return nil
        }
    }

    /// Solver move index: `face * 3 + (turns - 1)` with faces in U R F D L B order.
    var index: Int {
        Face.allCases.firstIndex(of: face)! * 3 + turns - 1
    }
}

extension Scramble {
    /// Parses space-separated WCA notation, e.g. `R U' F2`.
    init?(parsing notation: String) {
        var moves: [Move] = []
        for token in notation.split(separator: " ") {
            guard let move = Move(notation: token) else { return nil }
            moves.append(move)
        }
        self.init(moves)
    }
}

extension CubieCube {
    func applying(_ scramble: Scramble) -> CubieCube {
        scramble.moves.reduce(self) { $0.applying($1.index) }
    }
}

extension CubieCube {
    // Facelet indices: U 0-8, R 9-17, F 18-26, D 27-35, L 36-44, B 45-53.
    static let cornerFacelet: [[Int]] = [
        [8, 9, 20], [6, 18, 38], [0, 36, 47], [2, 45, 11],
        [29, 26, 15], [27, 44, 24], [33, 53, 42], [35, 17, 51],
    ]
    static let edgeFacelet: [[Int]] = [
        [5, 10], [7, 19], [3, 37], [1, 46], [32, 16], [28, 25],
        [30, 43], [34, 52], [23, 12], [21, 41], [50, 39], [48, 14],
    ]

    /// 54-character facelet string in URFDLB order, as used by min2phase and Kociemba's solver.
    var facelets: String {
        let names: [Character] = ["U", "R", "F", "D", "L", "B"]
        var f = (0..<54).map { names[$0 / 9] }
        for c in 0..<8 {
            let j = ca[c] & 7
            let ori = ca[c] >> 3
            for n in 0..<3 {
                f[Self.cornerFacelet[c][(n + ori) % 3]] = names[Self.cornerFacelet[j][n] / 9]
            }
        }
        for e in 0..<12 {
            let j = ea[e] >> 1
            let ori = ea[e] & 1
            for n in 0..<2 {
                f[Self.edgeFacelet[e][(n + ori) % 2]] = names[Self.edgeFacelet[j][n] / 9]
            }
        }
        return String(f)
    }
}
