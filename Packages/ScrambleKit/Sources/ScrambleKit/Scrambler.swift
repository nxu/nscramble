/// Generates WCA-style random-state 3x3x3 scrambles.
///
/// Follows cubing.js / TNoodle: pick a uniformly random reachable state, reject states that are
/// solved or one move from solved, then use a min2phase (two-phase) solution of at most 21 moves.
///
/// Creating the first instance builds the solver tables (a fraction of a second in release builds);
/// later instances share them. `randomScramble()` is safe to call from any thread.
public final class Scrambler: Sendable {
    public static let maxLength = 21

    public init() {
        _ = Tables.shared
    }

    public func randomScramble() -> Scramble {
        var generator = SystemRandomNumberGenerator()
        return randomScramble(using: &generator)
    }

    public func randomScramble<G: RandomNumberGenerator>(using generator: inout G) -> Scramble {
        while true {
            let state = CubieCube.random(using: &generator)
            if let scramble = scramble(for: state) {
                return scramble
            }
        }
    }

    /// A scramble that takes a solved cube to `state`, or nil if `state` fails the WCA filter.
    func scramble(for state: CubieCube) -> Scramble? {
        guard Self.passesFilter(state) else { return nil }
        let moves = Search().solution(state, maxDepth: Self.maxLength, inverse: true)
        return moves.map { Scramble($0.map(Move.init(index:))) }
    }

    /// Rejects states that are solved or a single move away from solved.
    static func passesFilter(_ state: CubieCube) -> Bool {
        state != .solved && !CubieCube.moveCube.contains(state)
    }
}
