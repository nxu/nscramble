import Testing
@testable import ScrambleKit

@Suite struct ScramblerTests {
    let scrambler = Scrambler()

    @Test func scrambleGeneratesTheRandomState() throws {
        var rng = SplitMix64(state: 42)
        for _ in 0..<200 {
            let state = CubieCube.random(using: &rng)
            let scramble = try #require(scrambler.scramble(for: state))
            #expect(CubieCube.solved.applying(scramble) == state)
            #expect(scramble.moves.count <= Scrambler.maxLength)
        }
    }

    @Test func scramblesHaveNoRedundantMoves() {
        var rng = SplitMix64(state: 7)
        for _ in 0..<200 {
            let moves = scrambler.randomScramble(using: &rng).moves
            for (a, b) in zip(moves, moves.dropFirst()) {
                #expect(a.face != b.face, "\(moves)")
            }
            // No "R L R": a face must not repeat around a move on the opposite face.
            for i in moves.indices.dropFirst(2) where axis(moves[i - 1]) == axis(moves[i]) {
                #expect(moves[i].face != moves[i - 2].face, "\(moves)")
            }
        }
    }

    private func axis(_ move: Move) -> Int {
        move.index / 3 % 3
    }

    @Test func solverSolves() throws {
        var rng = SplitMix64(state: 3)
        for _ in 0..<100 {
            let state = CubieCube.random(using: &rng)
            let solution = try #require(Search().solution(state))
            #expect(solution.reduce(state) { $0.applying($1) } == .solved)
        }
    }

    @Test func filterRejectsTrivialStates() {
        #expect(!Scrambler.passesFilter(.solved))
        for m in 0..<18 {
            #expect(!Scrambler.passesFilter(CubieCube.solved.applying(m)))
        }
        #expect(Scrambler.passesFilter(CubieCube.solved.applying(0).applying(3)))
        #expect(scrambler.scramble(for: .solved) == nil)
    }

    @Test func handlesSymmetricStates() throws {
        // Superflip and checkerboard-like patterns exercise the self-symmetry code paths.
        for notation in [
            "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2",
            "U2 D2 F2 B2 L2 R2",
        ] {
            let target = CubieCube.solved.applying(try #require(Scramble(parsing: notation)))
            let scramble = try #require(scrambler.scramble(for: target))
            #expect(CubieCube.solved.applying(scramble) == target)
        }
    }
}
