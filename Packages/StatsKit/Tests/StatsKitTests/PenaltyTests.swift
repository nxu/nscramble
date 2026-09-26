import Testing
@testable import StatsKit

@Test func effectiveTime() {
    #expect(SolveResult(timeMs: 9_870).effectiveMs == 9_870)
    #expect(SolveResult(timeMs: 9_870, penalty: .plusTwo).effectiveMs == 11_870)
    #expect(SolveResult(timeMs: 9_870, penalty: .dnf).effectiveMs == nil)
}
