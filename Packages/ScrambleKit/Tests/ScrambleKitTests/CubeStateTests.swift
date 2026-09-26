import Testing
@testable import ScrambleKit

@Test func solvedFacelets() {
    #expect(CubieCube.solved.facelets == "UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB")
}

/// Example from the min2phase README.
@Test func min2phaseExample() throws {
    let scramble = try #require(Scramble(parsing: "F U' F2 D' B U R' F' L D' R' U' L U B' D2 R' F U2 D2"))
    #expect(CubieCube.solved.applying(scramble).facelets == "FBLLURRFBUUFBRFDDFUULLFRDDLRFBLDRFBLUUBFLBDDBUURRBLDDR")
}

/// Cube states computed by cubing.js for the same move sequences.
@Test(arguments: CubingJSCase.all)
func matchesCubingJS(_ c: CubingJSCase) throws {
    let scramble = try #require(Scramble(parsing: c.scramble))
    #expect(CubieCube.solved.applying(scramble).facelets == c.facelets)
}

@Test func randomStatesAreSolvable() {
    var rng = SplitMix64(state: 1)
    for _ in 0..<1000 {
        #expect(CubieCube.random(using: &rng).isSolvable)
    }
}
