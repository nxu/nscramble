import Testing
@testable import ScrambleKit

@Test func notation() {
    let scramble = Scramble([Move(.R), Move(.U, 3), Move(.F, 2)])
    #expect(scramble.description == "R U' F2")
}
