import Testing
@testable import ScrambleKit

@Test func formatsNotation() {
    #expect(Scramble([Move(.R), Move(.U, 3), Move(.F, 2)]).description == "R U' F2")
}

@Test func parsesNotation() {
    #expect(Scramble(parsing: "R U' F2")?.description == "R U' F2")
    #expect(Scramble(parsing: "R U3") == nil)
    #expect(Scramble(parsing: "Rw") == nil)
}

@Test func moveIndexRoundTrips() {
    for i in 0..<18 {
        #expect(Move(index: i).index == i)
    }
}
