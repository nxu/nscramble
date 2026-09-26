import Foundation

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
