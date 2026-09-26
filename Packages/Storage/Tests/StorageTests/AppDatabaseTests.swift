import Testing
import GRDB
@testable import Storage

@Test func migratesSchema() throws {
    let db = try AppDatabase.inMemory()
    let tables = try db.writer.read { db in
        try String.fetchSet(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
    }
    #expect(tables.isSuperset(of: ["sessions", "solves"]))
}
