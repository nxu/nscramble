import Foundation
import GRDB
import StatsKit

/// A solve as sent to and received from the sync server (`worker/`): snake_case, epoch milliseconds.
public struct SyncSolve: Codable, Equatable, Sendable {
    public var id: String
    public var created_at: Int64
    public var date: String
    public var time_ms: Int
    public var scramble: String
    public var penalty: Int
    public var updated_at: Int64
    public var deleted_at: Int64?

    init(_ solve: Solve) {
        id = solve.id.databaseString
        created_at = solve.createdAt.milliseconds
        date = solve.date
        time_ms = solve.timeMs
        scramble = solve.scramble
        penalty = solve.penalty.rawValue
        updated_at = solve.updatedAt.milliseconds
        deleted_at = solve.deletedAt?.milliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case id, created_at, date, time_ms, scramble, penalty, updated_at, deleted_at
    }

    /// Always writes `deleted_at`, as `null` when not deleted (synthesized Codable would omit it).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(created_at, forKey: .created_at)
        try c.encode(date, forKey: .date)
        try c.encode(time_ms, forKey: .time_ms)
        try c.encode(scramble, forKey: .scramble)
        try c.encode(penalty, forKey: .penalty)
        try c.encode(updated_at, forKey: .updated_at)
        try c.encode(deleted_at, forKey: .deleted_at)
    }

    /// Nil if the server sent something this app can't store.
    var solve: Solve? {
        guard let id = UUID(uuidString: id), let penalty = Penalty(rawValue: penalty) else { return nil }
        return Solve(
            id: id, createdAt: Date(milliseconds: created_at), date: date, timeMs: time_ms, scramble: scramble,
            penalty: penalty, updatedAt: Date(milliseconds: updated_at), deletedAt: deleted_at.map(Date.init(milliseconds:)))
    }
}

public struct SyncRequest: Codable, Sendable {
    public var since: Int64
    public var changes: [SyncSolve]
}

public struct SyncResponse: Codable, Sendable {
    public var rev: Int64
    public var more: Bool
    public var changes: [SyncSolve]
}

/// Sends one sync round trip. `HTTPSyncTransport` talks to the worker; tests can fake it.
public protocol SyncTransport: Sendable {
    func send(_ request: SyncRequest) async throws -> SyncResponse
}

public enum SyncError: LocalizedError, Equatable {
    case unauthorized
    case server(status: Int, message: String?)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "The API key was rejected."
        case .server(let status, let message): "Server error \(status)\(message.map { ": \($0)" } ?? "")."
        case .invalidResponse: "Unexpected response from the server."
        }
    }
}

public struct HTTPSyncTransport: SyncTransport {
    public let baseURL: URL
    public let apiKey: String
    public let session: URLSession

    public init(baseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    public func send(_ request: SyncRequest) async throws -> SyncResponse {
        var urlRequest = URLRequest(url: baseURL.appending(path: "sync"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw SyncError.invalidResponse }
        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(SyncResponse.self, from: data)
            } catch {
                throw SyncError.invalidResponse
            }
        case 401:
            throw SyncError.unauthorized
        default:
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw SyncError.server(status: http.statusCode, message: message)
        }
    }
}

public struct SyncResult: Equatable, Sendable {
    /// Local changes accepted by the server.
    public var pushed: Int
    /// Solves added or updated locally from the server.
    public var pulled: Int
}

extension AppDatabase {
    /// Pushes local changes and pulls remote ones until both sides are up to date.
    /// Conflicts resolve by last write wins (`updated_at`), on the server and locally.
    @discardableResult
    public func sync(using transport: some SyncTransport, batchSize: Int = 200) async throws -> SyncResult {
        var result = SyncResult(pushed: 0, pulled: 0)
        while true {
            let (pending, since) = try await writer.read { db in
                (try Self.pendingSyncSolves(db, limit: batchSize), try Self.syncCursor(db))
            }
            let response = try await transport.send(SyncRequest(since: since, changes: pending))
            result.pulled += try await writer.write { db in
                try Self.apply(response, pushed: pending, db)
            }
            result.pushed += pending.count
            if pending.count < batchSize && !response.more {
                return result
            }
        }
    }

    /// Local changes not yet accepted by the server.
    public func pendingSyncCount() throws -> Int {
        try writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM solves WHERE needs_push = 1") ?? 0 }
    }

    static func pendingSyncSolves(_ db: Database, limit: Int) throws -> [SyncSolve] {
        try Solve.fetchAll(db, sql: "SELECT * FROM solves WHERE needs_push = 1 ORDER BY updated_at LIMIT ?", arguments: [limit])
            .map(SyncSolve.init)
    }

    static func syncCursor(_ db: Database) throws -> Int64 {
        try String.fetchOne(db, sql: "SELECT value FROM sync_state WHERE key = 'cursor'").flatMap { Int64($0) } ?? 0
    }

    /// Returns the number of solves changed locally.
    static func apply(_ response: SyncResponse, pushed: [SyncSolve], _ db: Database) throws -> Int {
        // Accepted pushes are clean, unless edited again while the request was in flight.
        for solve in pushed {
            try db.execute(
                sql: "UPDATE solves SET needs_push = 0 WHERE id = ? AND updated_at = ?",
                arguments: [solve.id, solve.updated_at])
        }

        var changed = 0
        for remote in response.changes {
            guard let solve = remote.solve else { continue }
            if let local = try Solve.fetchOne(db, key: solve.id) {
                // Same or older than ours (including our own pushes coming back): keep ours.
                guard solve.updatedAt > local.updatedAt else { continue }
                try solve.update(db)
            } else {
                try solve.insert(db)
            }
            try db.execute(sql: "UPDATE solves SET needs_push = 0 WHERE id = ?", arguments: [remote.id])
            changed += 1
        }

        try db.execute(
            sql: """
                INSERT INTO sync_state (key, value) VALUES ('cursor', ?)
                ON CONFLICT (key) DO UPDATE SET value = excluded.value
                """,
            arguments: [String(response.rev)])
        return changed
    }
}
