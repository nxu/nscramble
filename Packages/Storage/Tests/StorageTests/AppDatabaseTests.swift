import Foundation
import GRDB
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
