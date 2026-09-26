import GRDB

/// Owns the local SQLite database and its schema.
///
/// The schema mirrors `worker/migrations` so rows sync to D1 unchanged:
/// UUIDv7 text ids, epoch-millisecond timestamps, and soft deletes via `deleted_at`.
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// In-memory database for tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE sessions (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL,
                    deleted_at INTEGER
                );
                CREATE TABLE solves (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL REFERENCES sessions(id),
                    scramble TEXT NOT NULL,
                    time_ms INTEGER NOT NULL,
                    penalty INTEGER NOT NULL DEFAULT 0,
                    comment TEXT,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL,
                    deleted_at INTEGER
                );
                CREATE INDEX solves_session_created ON solves(session_id, created_at);
                CREATE INDEX solves_updated ON solves(updated_at);
                CREATE INDEX sessions_updated ON sessions(updated_at);
                """)
        }
        return migrator
    }
}
