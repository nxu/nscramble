import Foundation
import Observation
import ScrambleKit
import StatsKit
import Storage
import TimerKit

@MainActor
@Observable
final class AppModel {
    private(set) var scramble: Scramble?
    private(set) var timer = SpeedTimer()
    private(set) var lastSolve: Solve?
    private(set) var stats: StatsSummary?
    /// All of today's solves, newest first.
    private(set) var todaysSolves: [Solve] = []
    private(set) var errorMessage: String?

    enum SyncStatus: Equatable {
        case never
        case syncing
        case synced(Date)
        case failed(String)
    }

    private(set) var syncStatus = SyncStatus.never
    private(set) var hasAPIKey = Keychain.read(AppModel.apiKeyAccount) != nil
    /// Base URL of the sync server, e.g. `https://sync.example.com`.
    private(set) var syncURL = UserDefaults.standard.string(forKey: "syncURL") ?? ""
    private static let apiKeyAccount = "sync-api-key"
    /// Sync on launch, every `autoSyncInterval` while the app is open, and after every `autoSyncSolveCount` solves.
    var autoSync = UserDefaults.standard.object(forKey: "autoSync") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoSync, forKey: "autoSync") }
    }
    static let autoSyncInterval = Duration.seconds(60 * 60)
    static let autoSyncSolveCount = 10
    /// Solves recorded since the last sync (manual or automatic).
    @ObservationIgnored private var solvesSinceSync = 0

    var appearance = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    /// Compact window layout (macOS). Remembered across launches.
    var isMiniMode = UserDefaults.standard.bool(forKey: "isMiniMode") {
        didSet { UserDefaults.standard.set(isMiniMode, forKey: "isMiniMode") }
    }

    private let database: AppDatabase
    @ObservationIgnored private var scrambler: Scrambler?
    @ObservationIgnored private var upcoming: Task<Scramble, Never>?

    init() {
        do {
            database = try AppDatabase.openDefault()
        } catch {
            database = try! AppDatabase.inMemory()
            errorMessage = "Couldn't open the database; solves won't be saved. \(error.localizedDescription)"
        }
        Task { await advanceScramble() }
        Task { await runAutoSync() }
    }

    // MARK: Timer input

    /// Monotonic time, same base as NSEvent/UITouch timestamps.
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Key or touch down. `penalty` applies if this stops the timer (e.g. Esc records a DNF).
    func press(penalty: Penalty = .none) {
        // Don't start a solve before there is a scramble to record.
        guard scramble != nil || timer.isRunning else { return }
        if let timeMs = timer.press(at: now) {
            finishSolve(timeMs: timeMs, penalty: penalty)
        }
    }

    func release() {
        timer.release(at: now)
    }

    func cancelHold() {
        timer.cancelHold()
    }

    private func finishSolve(timeMs: Int, penalty: Penalty) {
        guard let scramble else { return }
        do {
            lastSolve = try database.addSolve(timeMs: timeMs, scramble: scramble.description, penalty: penalty)
            refreshStats()
            solvesSinceSync += 1
            if solvesSinceSync >= Self.autoSyncSolveCount && autoSync && isSyncConfigured {
                Task { await syncNow() }
            }
        } catch {
            errorMessage = "Couldn't save the solve. \(error.localizedDescription)"
        }
        Task { await advanceScramble() }
    }

    // MARK: Sync

    private var isSyncConfigured: Bool {
        Self.validSyncURL(syncURL) != nil && hasAPIKey
    }

    /// Syncs at launch, then every `autoSyncInterval`, when enabled and configured.
    /// (The every-N-solves trigger is in `finishSolve`.)
    private func runAutoSync() async {
        while !Task.isCancelled {
            if autoSync && isSyncConfigured {
                await syncNow()
            }
            try? await Task.sleep(for: Self.autoSyncInterval)
        }
    }

    func syncNow() async {
        guard syncStatus != .syncing else { return }
        guard let url = Self.validSyncURL(syncURL), let apiKey = Keychain.read(Self.apiKeyAccount) else {
            syncStatus = .failed("Set the server URL and API key first.")
            return
        }
        syncStatus = .syncing
        solvesSinceSync = 0
        do {
            let transport = HTTPSyncTransport(baseURL: url, apiKey: apiKey)
            try await database.sync(using: transport, serverID: transport.serverID)
            syncStatus = .synced(Date())
            refreshStats()
            if let id = lastSolve?.id {
                lastSolve = try database.solve(id: id)
            }
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    /// Saves the server URL, and the API key unless `apiKey` is empty (keeps the stored one).
    func saveSyncSettings(url: String, apiKey: String) throws {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.validSyncURL(url) != nil else {
            throw NSError(domain: "NScramble", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Enter an https:// URL (http:// only for localhost).",
            ])
        }
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            try Keychain.write(apiKey, account: Self.apiKeyAccount)
            hasAPIKey = true
        }
        syncURL = url
        UserDefaults.standard.set(url, forKey: "syncURL")
        if case .failed = syncStatus {
            syncStatus = .never
        }
    }

    func removeAPIKey() {
        Keychain.delete(Self.apiKeyAccount)
        hasAPIKey = false
    }

    static func validSyncURL(_ string: String) -> URL? {
        guard let url = URL(string: string), let host = url.host(), !host.isEmpty else { return nil }
        switch url.scheme {
        case "https": return url
        case "http" where host == "localhost" || host == "127.0.0.1": return url
        default: return nil
        }
    }

    // MARK: Stats

    func refreshStats() {
        do {
            stats = try database.statsSummary()
            todaysSolves = try database.solves(onDay: Solve.day(of: Date()))
        } catch {
            errorMessage = "Couldn't load statistics. \(error.localizedDescription)"
        }
    }

    // MARK: Last solve


    /// Sets `penalty` on the last solve, or clears it if already set.
    func togglePenalty(_ penalty: Penalty) {
        guard let solve = lastSolve else { return }
        do {
            lastSolve = try database.setPenalty(solve.penalty == penalty ? .none : penalty, forSolve: solve.id)
            refreshStats()
        } catch {
            errorMessage = "Couldn't update the solve. \(error.localizedDescription)"
        }
    }

    /// Clears any penalty and restores the last solve if it was deleted.
    func markLastSolveOK() {
        guard let solve = lastSolve else { return }
        do {
            lastSolve = try database.markOK(solve.id)
            refreshStats()
        } catch {
            errorMessage = "Couldn't update the solve. \(error.localizedDescription)"
        }
    }

    /// Soft-deletes the last solve; it stays on screen so it can be restored with OK.
    func deleteLastSolve() {
        guard let solve = lastSolve else { return }
        do {
            lastSolve = try database.deleteSolve(solve.id)
            refreshStats()
        } catch {
            errorMessage = "Couldn't delete the solve. \(error.localizedDescription)"
        }
    }

    // MARK: Scrambles

    func skipScramble() {
        guard timer.state == .idle else { return }
        Task { await advanceScramble() }
    }

    /// Shows the pre-generated scramble and starts generating the next one off the main thread.
    private func advanceScramble() async {
        scramble = nil
        if upcoming == nil {
            upcoming = await makeScrambleTask()
        }
        scramble = await upcoming?.value
        upcoming = await makeScrambleTask()
    }

    private func makeScrambleTask() async -> Task<Scramble, Never> {
        let scrambler: Scrambler
        if let existing = self.scrambler {
            scrambler = existing
        } else {
            // First use builds the solver tables; keep that off the main thread.
            scrambler = await Task.detached(priority: .userInitiated) { Scrambler() }.value
            self.scrambler = scrambler
        }
        return Task.detached(priority: .userInitiated) { scrambler.randomScramble() }
    }
}
