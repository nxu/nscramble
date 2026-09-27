import Foundation
import GRDB
import StatsKit

/// Owns the local SQLite database: schema and solve queries.
///
/// Rows use UUIDv7 text ids, epoch-millisecond timestamps and soft deletes (`deleted_at`).
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// Opens (or creates) the database file at `url`.
    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try AppDatabase(DatabasePool(path: url.path))
    }

    /// `Application Support/NScramble/nscramble.sqlite`.
    public static func openDefault() throws -> AppDatabase {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return try open(at: support.appending(path: "NScramble/nscramble.sqlite"))
    }

    /// In-memory database for tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE solves (
                    id TEXT PRIMARY KEY NOT NULL,
                    created_at INTEGER NOT NULL,
                    time_ms INTEGER NOT NULL,
                    scramble TEXT NOT NULL,
                    penalty INTEGER NOT NULL DEFAULT 0 CHECK (penalty IN (0, 1, 2)),
                    updated_at INTEGER NOT NULL,
                    deleted_at INTEGER
                );
                CREATE INDEX solves_created_at ON solves(created_at);
                """)
        }
        migrator.registerMigration("v2: solve date") { db in
            // Local calendar day of the solve, YYYY-MM-DD, for day-based queries.
            try db.execute(sql: """
                ALTER TABLE solves ADD COLUMN date TEXT NOT NULL DEFAULT '';
                UPDATE solves SET date = date(created_at / 1000, 'unixepoch', 'localtime');
                CREATE INDEX solves_date ON solves(date);
                """)
        }
        migrator.registerMigration("v3: sync") { db in
            // needs_push: changed locally and not yet accepted by the sync server.
            try db.execute(sql: """
                ALTER TABLE solves ADD COLUMN needs_push INTEGER NOT NULL DEFAULT 1;
                CREATE INDEX solves_needs_push ON solves(needs_push) WHERE needs_push = 1;
                CREATE TABLE sync_state (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                );
                """)
        }
        return migrator
    }
}

// MARK: Solves

extension AppDatabase {
    /// Records a new solve and returns it.
    @discardableResult
    public func addSolve(timeMs: Int, scramble: String, penalty: Penalty = .none, at date: Date = Date()) throws -> Solve {
        let date = date.truncatedToMilliseconds
        let solve = Solve(
            id: .v7(date: date), createdAt: date, date: Solve.day(of: date), timeMs: timeMs, scramble: scramble,
            penalty: penalty, updatedAt: date, deletedAt: nil)
        try writer.write { try solve.insert($0) }
        return solve
    }

    /// Changes a solve's penalty and returns the updated solve.
    @discardableResult
    public func setPenalty(_ penalty: Penalty, forSolve id: UUID, at date: Date = Date()) throws -> Solve? {
        let date = date.truncatedToMilliseconds
        return try writer.write { db -> Solve? in
            guard var solve = try Solve.fetchOne(db, key: id) else { return nil }
            solve.penalty = penalty
            solve.updatedAt = date
            try solve.update(db)
            try Solve.markNeedsPush(solve.id, db)
            return solve
        }
    }

    /// Soft-deletes a solve and returns it.
    @discardableResult
    public func deleteSolve(_ id: UUID, at date: Date = Date()) throws -> Solve? {
        let date = date.truncatedToMilliseconds
        return try writer.write { db -> Solve? in
            guard var solve = try Solve.fetchOne(db, key: id) else { return nil }
            solve.deletedAt = date
            solve.updatedAt = date
            try solve.update(db)
            try Solve.markNeedsPush(solve.id, db)
            return solve
        }
    }

    /// Marks a solve as a plain success: clears any penalty and restores it if deleted.
    @discardableResult
    public func markOK(_ id: UUID, at date: Date = Date()) throws -> Solve? {
        let date = date.truncatedToMilliseconds
        return try writer.write { db -> Solve? in
            guard var solve = try Solve.fetchOne(db, key: id) else { return nil }
            solve.penalty = .none
            solve.deletedAt = nil
            solve.updatedAt = date
            try solve.update(db)
            try Solve.markNeedsPush(solve.id, db)
            return solve
        }
    }

    /// Non-deleted solves of one local calendar day (`YYYY-MM-DD`), newest first.
    public func solves(onDay day: String) throws -> [Solve] {
        try writer.read { db in
            try Solve.active
                .filter(Solve.Columns.date == day)
                .order(Solve.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    public func solve(id: UUID) throws -> Solve? {
        try writer.read { try Solve.fetchOne($0, key: id) }
    }

}

extension Date {
    /// Exactly `milliseconds` after 1970.
    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    /// Milliseconds since 1970, as stored in the database and sent to the sync server.
    var milliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }

    /// The database stores milliseconds; truncate so in-memory values match what's stored.
    var truncatedToMilliseconds: Date {
        Date(milliseconds: Int64((timeIntervalSince1970 * 1000).rounded(.down)))
    }
}
