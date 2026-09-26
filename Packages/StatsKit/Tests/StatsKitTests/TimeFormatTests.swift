import Testing
@testable import StatsKit

@Test(arguments: [
    (0, "0.00"),
    (9_876, "9.87"),
    (12_349, "12.34"),
    (59_999, "59.99"),
    (60_000, "1:00.00"),
    (62_345, "1:02.34"),
    (3_723_450, "62:03.45"),
])
func formatsTime(ms: Int, expected: String) {
    #expect(TimeFormat.string(ms: ms) == expected)
}

@Test func formatsResults() {
    #expect(SolveResult(timeMs: 12_345).formatted == "12.34")
    #expect(SolveResult(timeMs: 12_345, penalty: .plusTwo).formatted == "14.34+")
    #expect(SolveResult(timeMs: 12_345, penalty: .dnf).formatted == "DNF")
}
