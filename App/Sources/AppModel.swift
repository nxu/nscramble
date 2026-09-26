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
    /// Up to 10 most recent solves of today, newest first.
    private(set) var todaysRecentSolves: [Solve] = []
    private(set) var errorMessage: String?

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
        } catch {
            errorMessage = "Couldn't save the solve. \(error.localizedDescription)"
        }
        Task { await advanceScramble() }
    }

    // MARK: Stats

    func refreshStats() {
        do {
            stats = try database.statsSummary()
            todaysRecentSolves = try database.solves(onDay: Solve.day(of: Date()), limit: 10)
        } catch {
            errorMessage = "Couldn't load statistics. \(error.localizedDescription)"
        }
    }

    // MARK: Last solve

    /// Whether the last solve can be edited right now (not while timing).
    var canEditLastSolve: Bool {
        lastSolve != nil && timer.state == .idle
    }

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
