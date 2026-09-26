import Foundation
import StatsKit
import Testing
@testable import Storage

/// In-memory stand-in for the worker, with the same rules: last write wins, revisions as cursor.
final class FakeSyncServer: SyncTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var rows: [String: (solve: SyncSolve, rev: Int64)] = [:]
    private var rev: Int64 = 0
    let pullLimit: Int
    var beforeResponding: (@Sendable () throws -> Void)?

    init(pullLimit: Int = 500) {
        self.pullLimit = pullLimit
    }

    func send(_ request: SyncRequest) async throws -> SyncResponse {
        try beforeResponding?()
        return lock.withLock {
            for solve in request.changes {
                if let existing = rows[solve.id], solve.updated_at <= existing.solve.updated_at { continue }
                rev += 1
                rows[solve.id] = (solve, rev)
            }
            let newer = rows.values.filter { $0.rev > request.since }.sorted { $0.rev < $1.rev }
            let page = newer.prefix(pullLimit)
            return SyncResponse(
                rev: page.last?.rev ?? request.since, more: newer.count > pullLimit, changes: page.map(\.solve))
        }
    }

    var storedCount: Int { lock.withLock { rows.count } }
}

@Test func twoDevicesConverge() async throws {
    let server = FakeSyncServer()
    let mac = try AppDatabase.inMemory()
    let ipad = try AppDatabase.inMemory()

    let a = try mac.addSolve(timeMs: 12_345, scramble: "R U")
    let b = try mac.addSolve(timeMs: 9_876, scramble: "F2")
    #expect(try mac.pendingSyncCount() == 2)
    #expect(try await mac.sync(using: server) == SyncResult(pushed: 2, pulled: 0))
    #expect(try mac.pendingSyncCount() == 0)

    #expect(try await ipad.sync(using: server) == SyncResult(pushed: 0, pulled: 2))
    #expect(try ipad.solves() == mac.solves())

    // Edits and deletes flow back.
    try await Task.sleep(for: .milliseconds(2))
    try ipad.setPenalty(.dnf, forSolve: a.id)
    try ipad.deleteSolve(b.id)
    try await ipad.sync(using: server)
    #expect(try await mac.sync(using: server) == SyncResult(pushed: 0, pulled: 2))
    #expect(try mac.solves().map(\.penalty) == [.dnf])
    #expect(try mac.solves() == ipad.solves())
    #expect(try mac.pendingSyncCount() == 0)
}

@Test func newerLocalEditSurvivesOlderRemoteEdit() async throws {
    let server = FakeSyncServer()
    let mac = try AppDatabase.inMemory()
    let ipad = try AppDatabase.inMemory()
    let solve = try mac.addSolve(timeMs: 10_000, scramble: "U", at: Date(timeIntervalSince1970: 100))
    try await mac.sync(using: server)
    try await ipad.sync(using: server)

    try mac.setPenalty(.plusTwo, forSolve: solve.id, at: Date(timeIntervalSince1970: 200))
    try ipad.setPenalty(.dnf, forSolve: solve.id, at: Date(timeIntervalSince1970: 300))
    try await mac.sync(using: server)
    try await ipad.sync(using: server)  // newer: wins on the server
    try await mac.sync(using: server)

    #expect(try mac.solves().first?.penalty == .dnf)
    #expect(try ipad.solves().first?.penalty == .dnf)
}

@Test func editDuringSyncIsPushedNextTime() async throws {
    let server = FakeSyncServer()
    let mac = try AppDatabase.inMemory()
    let solve = try mac.addSolve(timeMs: 10_000, scramble: "U", at: Date(timeIntervalSince1970: 100))
    server.beforeResponding = {
        try mac.setPenalty(.dnf, forSolve: solve.id, at: Date(timeIntervalSince1970: 200))
    }
    try await mac.sync(using: server)
    #expect(try mac.pendingSyncCount() == 1)

    server.beforeResponding = nil
    try await mac.sync(using: server)
    #expect(try mac.pendingSyncCount() == 0)
    #expect(try mac.solves().first?.penalty == .dnf)
}

@Test func syncsInBatchesAndPages() async throws {
    let server = FakeSyncServer(pullLimit: 7)
    let mac = try AppDatabase.inMemory()
    let ipad = try AppDatabase.inMemory()
    for i in 0..<25 {
        try mac.addSolve(timeMs: i, scramble: "U", at: Date(timeIntervalSince1970: Double(i)))
    }
    #expect(try await mac.sync(using: server, batchSize: 10) == SyncResult(pushed: 25, pulled: 0))
    #expect(server.storedCount == 25)
    #expect(try await ipad.sync(using: server) == SyncResult(pushed: 0, pulled: 25))
    #expect(try ipad.solves().count == 25)
}

@Test func timestampsSurviveTheRoundTripExactly() async throws {
    let server = FakeSyncServer()
    let mac = try AppDatabase.inMemory()
    let ipad = try AppDatabase.inMemory()
    // Sub-millisecond parts and values that don't have exact binary fractions.
    for t in [1_790_000_000.1234567, 1_790_000_000.123, 1_790_000_000.9999, 0.001] {
        try mac.addSolve(timeMs: 1, scramble: "U", at: Date(timeIntervalSince1970: t))
    }
    try await mac.sync(using: server)
    try await ipad.sync(using: server)
    #expect(try ipad.solves() == mac.solves())
    // Nothing looks newer on either side, so a second round moves nothing.
    #expect(try await mac.sync(using: server) == SyncResult(pushed: 0, pulled: 0))
    #expect(try await ipad.sync(using: server) == SyncResult(pushed: 0, pulled: 0))
}

@Test func rejectedAPIKeySurfacesAsUnauthorized() async throws {
    struct Rejecting: SyncTransport {
        func send(_ request: SyncRequest) async throws -> SyncResponse { throw SyncError.unauthorized }
    }
    let mac = try AppDatabase.inMemory()
    try mac.addSolve(timeMs: 1, scramble: "U")
    await #expect(throws: SyncError.unauthorized) { try await mac.sync(using: Rejecting()) }
    #expect(try mac.pendingSyncCount() == 1)
}

/// Against the real worker code: run `just worker-dev` first, then
/// `NSCRAMBLE_SYNC_URL=http://127.0.0.1:8788 swift test --filter liveWorker`.
@Test(.enabled(if: ProcessInfo.processInfo.environment["NSCRAMBLE_SYNC_URL"] != nil))
func liveWorker() async throws {
    let url = try #require(URL(string: ProcessInfo.processInfo.environment["NSCRAMBLE_SYNC_URL"]!))
    let transport = HTTPSyncTransport(baseURL: url, apiKey: ProcessInfo.processInfo.environment["NSCRAMBLE_SYNC_TOKEN"] ?? "dev-token")
    let mac = try AppDatabase.inMemory()
    let ipad = try AppDatabase.inMemory()
    let solve = try mac.addSolve(timeMs: 12_345, scramble: "R U R' U'")
    try await mac.sync(using: transport)
    try await ipad.sync(using: transport)
    #expect(try ipad.solves().contains(solve))

    try await Task.sleep(for: .milliseconds(2))
    try ipad.setPenalty(.plusTwo, forSolve: solve.id)
    try await ipad.sync(using: transport)
    try await mac.sync(using: transport)
    #expect(try mac.solves().first { $0.id == solve.id }?.penalty == .plusTwo)

    let wrongKey = HTTPSyncTransport(baseURL: url, apiKey: "wrong")
    await #expect(throws: SyncError.unauthorized) { try await mac.sync(using: wrongKey) }
}
