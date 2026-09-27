import GRDB
@testable import Storage

extension AppDatabase {
    /// Non-deleted solves, newest first.
    func solves(limit: Int? = nil) throws -> [Solve] {
        try writer.read { db in
            try Solve.active.order(Solve.Columns.createdAt.desc).limit(limit ?? -1).fetchAll(db)
        }
    }

    /// Local changes not yet accepted by the sync server.
    func pendingSyncCount() throws -> Int {
        try writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM solves WHERE needs_push = 1") ?? 0 }
    }
}
