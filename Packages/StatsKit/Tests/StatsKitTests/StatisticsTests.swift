import Testing
@testable import StatsKit

private func r(_ ms: Int) -> SolveResult { SolveResult(timeMs: ms) }
private let dnf = SolveResult(timeMs: 5_000, penalty: .dnf)

@Test func ao5DropsBestAndWorst() {
    let results = [r(10_000), r(12_000), r(11_000), r(9_000), r(20_000)]
    #expect(Statistics.average(results) == .time(ms: 11_000))
}

@Test func ao5WithOneDNFCountsItAsWorst() {
    #expect(Statistics.average([r(10_000), r(12_000), r(11_000), r(9_000), dnf]) == .time(ms: 11_000))
}

@Test func ao5WithTwoDNFsIsDNF() {
    #expect(Statistics.average([r(10_000), r(12_000), r(11_000), dnf, dnf]) == .dnf)
}

@Test func plusTwoIsIncluded() {
    let results = [r(10_000), SolveResult(timeMs: 10_000, penalty: .plusTwo), r(11_000), r(9_000), r(20_000)]
    // Kept: 10.00, 11.00, 12.00
    #expect(Statistics.average(results) == .time(ms: 11_000))
}

@Test func ao100TrimsFiveFromEachEnd() {
    // 1..100 seconds, plus 5 DNFs replacing the slowest: still trimmed away.
    var results = (1...95).map { r($0 * 1000) }
    results += Array(repeating: dnf, count: 5)
    // Kept: 6..95 -> mean 50.5 s
    #expect(Statistics.average(results) == .time(ms: 50_500))
    results[0] = dnf  // a 6th DNF survives the trim
    #expect(Statistics.average(results) == .dnf)
}

@Test func averageRoundsToCentiseconds() {
    // Kept: 10.001, 10.002, 10.004 -> 10.00233 -> 10.00
    #expect(Statistics.average([r(1), r(10_001), r(10_002), r(10_004), r(99_999)]) == .time(ms: 10_000))
    // Kept: 10.005, 10.005, 10.006 -> 10.00533 -> 10.01
    #expect(Statistics.average([r(1), r(10_005), r(10_005), r(10_006), r(99_999)]) == .time(ms: 10_010))
}

@Test func averageNeedsThreeResults() {
    #expect(Statistics.average([r(1), r(2)]) == .none)
    #expect(Statistics.average([r(1_000), r(2_000), r(9_000)]) == .time(ms: 2_000))
}

@Test func averageOfUsesMostRecent() {
    let newestFirst = [r(1_000), r(2_000), r(3_000), r(4_000), r(5_000), r(60_000)]
    #expect(Statistics.averageOf(5, newestFirst) == .time(ms: 3_000))
    #expect(Statistics.averageOf(12, newestFirst) == .none)
}

@Test func meanExcludesDNFs() {
    #expect(Statistics.mean([r(10_000), r(12_000), dnf]) == .time(ms: 11_000))
    #expect(Statistics.mean([dnf]) == .dnf)
    #expect(Statistics.mean([]) == .none)
}

@Test func summaryPeriods() {
    let dated: [(day: String, result: SolveResult)] = [
        ("2026-09-26", r(10_000)), ("2026-09-26", r(11_000)), ("2026-09-26", r(12_000)),
        ("2026-09-22", r(20_000)),
        ("2026-09-01", r(30_000)),
    ]
    let s = StatsSummary(
        dated: dated, newestFirst: dated.map(\.result),
        today: "2026-09-26", weekStart: "2026-09-20", monthStart: "2026-08-28")
    #expect(s.today.count == 3)
    #expect(s.today.average == .time(ms: 11_000))
    #expect(s.last7Days.count == 4)
    #expect(s.last7Days.mean == .time(ms: 13_250))
    #expect(s.last30Days.count == 5)
    #expect(s.ao5 == .time(ms: 14_330))  // 11, 12, 20
    #expect(s.ao12 == .none)
}

@Test func statFormatting() {
    #expect(Stat.time(ms: 12_340).formatted == "12.34")
    #expect(Stat.dnf.formatted == "DNF")
    #expect(Stat.none.formatted == "–")
}
