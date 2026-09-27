import Foundation
import GRDB
import StatsKit
import Testing
@testable import Storage

@Test func storesSolvesInPortableFormat() throws {
    let db = try AppDatabase.inMemory()
    let date = Date(timeIntervalSince1970: 1_790_000_000.123)
    let solve = try db.addSolve(timeMs: 12_345, scramble: "R U R' U'", at: date)

    let row = try #require(try db.writer.read { try Row.fetchOne($0, sql: "SELECT * FROM solves") })
    #expect(row["id"] as String == solve.id.uuidString.lowercased())
    #expect(row["created_at"] as Int64 == 1_790_000_000_123)
    #expect(row["date"] as String == Solve.day(of: date))
    #expect(row["time_ms"] as Int == 12_345)
    #expect(row["scramble"] as String == "R U R' U'")
    #expect(row["penalty"] as Int == 0)
    #expect(row["deleted_at"] as Int64? == nil)

    #expect(try db.solves() == [solve])
}

@Test func updatesPenalty() throws {
    let db = try AppDatabase.inMemory()
    let solve = try db.addSolve(timeMs: 9_000, scramble: "F", at: Date(timeIntervalSince1970: 100))
    let later = Date(timeIntervalSince1970: 200)
    let updated = try #require(try db.setPenalty(.plusTwo, forSolve: solve.id, at: later))
    #expect(updated.penalty == .plusTwo)
    #expect(updated.updatedAt == later)
    #expect(try db.solves().first?.penalty == .plusTwo)
}

@Test func softDeletes() throws {
    let db = try AppDatabase.inMemory()
    let keep = try db.addSolve(timeMs: 1, scramble: "U", at: Date(timeIntervalSince1970: 1))
    let drop = try db.addSolve(timeMs: 2, scramble: "D", at: Date(timeIntervalSince1970: 2))
    try db.deleteSolve(drop.id)
    #expect(try db.solves().map(\.id) == [keep.id])
    let count = try db.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM solves") }
    #expect(count == 2)
}

@Test func solvesAreNewestFirst() throws {
    let db = try AppDatabase.inMemory()
    for i in 0..<5 {
        try db.addSolve(timeMs: i, scramble: "U", at: Date(timeIntervalSince1970: Double(i)))
    }
    #expect(try db.solves(limit: 3).map(\.timeMs) == [4, 3, 2])
}

@Test func uuidV7IsTimeOrdered() {
    let a = UUID.v7(date: Date(timeIntervalSince1970: 1))
    let b = UUID.v7(date: Date(timeIntervalSince1970: 2))
    #expect(a.uuidString < b.uuidString)
    #expect(Array(a.uuidString)[14] == "7")
}

@Test func dayUsesLocalCalendar() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
    // 2026-09-25 23:30 UTC is already Sep 26 in Budapest.
    let date = Date(timeIntervalSince1970: 1_790_379_000)
    #expect(Solve.day(of: date, calendar: calendar) == "2026-09-26")
}

@Test func markOKRestoresAndClearsPenalty() throws {
    let db = try AppDatabase.inMemory()
    let solve = try db.addSolve(timeMs: 9_000, scramble: "F", penalty: .dnf)
    try db.deleteSolve(solve.id)
    #expect(try db.solves().isEmpty)
    let ok = try #require(try db.markOK(solve.id))
    #expect(ok.penalty == .none && !ok.isDeleted)
    #expect(try db.solves() == [ok])
}

@Test func v2BackfillsDateFromCreatedAt() throws {
    let queue = try DatabaseQueue()
    var v1 = DatabaseMigrator()
    v1.registerMigration("v1") { db in
        try db.execute(sql: """
            CREATE TABLE solves (id TEXT PRIMARY KEY NOT NULL, created_at INTEGER NOT NULL, time_ms INTEGER NOT NULL,
                scramble TEXT NOT NULL, penalty INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL, deleted_at INTEGER);
            INSERT INTO solves VALUES ('0199a7c1-1a2b-7c3d-8e4f-5a6b7c8d9e0f', 1790000000123, 1000, 'R', 0, 1790000000123, NULL);
            """)
    }
    try v1.migrate(queue)
    let db = try AppDatabase(queue)
    let solve = try #require(try db.solves().first)
    #expect(solve.date == Solve.day(of: solve.createdAt))
}

@Test func statsSummaryUsesLocalDaysAndSkipsDeleted() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12))!
    func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now)! }

    let db = try AppDatabase.inMemory()
    // Force day strings in the test time zone.
    func add(_ ms: Int, _ date: Date, penalty: Penalty = .none) throws -> Solve {
        let solve = try db.addSolve(timeMs: ms, scramble: "R", penalty: penalty, at: date)
        try db.writer.write {
            try $0.execute(sql: "UPDATE solves SET date = ? WHERE id = ?", arguments: [Solve.day(of: date, calendar: calendar), solve.id])
        }
        return solve
    }
    for ms in [10_000, 11_000, 12_000] { _ = try add(ms, now) }
    let deleted = try add(1_000, now)
    try db.deleteSolve(deleted.id)
    _ = try add(20_000, daysAgo(6))  // still in the last 7 days
    _ = try add(30_000, daysAgo(7))  // not in the last 7 days
    _ = try add(40_000, daysAgo(29))  // last day of the 30-day window
    _ = try add(50_000, daysAgo(30))  // outside

    let s = try db.statsSummary(now: now, calendar: calendar)
    // Each average differs depending on which solves the period includes.
    #expect(s.today == .time(ms: 11_000))  // 10, 11, 12 (the deleted 1.00 would give 10.50)
    #expect(s.last7Days == .time(ms: 11_500))  // + 20 from 6 days ago (30 from 7 days ago would give 14.33)
    #expect(s.last30Days == .time(ms: 18_250))  // + 30, 40 -> 11, 12, 20, 30 (50 from 30 days ago would give 22.60)
    // Newest five: 10, 11, 12 (today), 20, 30 -> trimmed to 11, 12, 20.
    #expect(s.ao5 == .time(ms: 14_330))
}

@Test func solvesOnDayAreNewestFirstAndSkipDeleted() throws {
    let db = try AppDatabase.inMemory()
    let day = Date(timeIntervalSince1970: 1_790_000_000)
    var ids: [UUID] = []
    for i in 0..<12 {
        ids.append(try db.addSolve(timeMs: 1_000 + i, scramble: "U", at: day.addingTimeInterval(Double(i))).id)
    }
    try db.addSolve(timeMs: 99, scramble: "U", at: day.addingTimeInterval(-3 * 86_400))  // other day
    try db.deleteSolve(ids[11])

    let solves = try db.solves(onDay: Solve.day(of: day))
    #expect(solves.map(\.timeMs) == Array((1_000...1_010).reversed()))
}
