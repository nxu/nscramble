import Foundation
import GRDB
import StatsKit

extension AppDatabase {
    /// Today, last 7 and last 30 days (each including today, by local calendar day), plus ao5/ao12/ao100.
    public func statsSummary(now: Date = Date(), calendar: Calendar = .current) throws -> StatsSummary {
        let today = Solve.day(of: now, calendar: calendar)
        let weekStart = Solve.day(of: calendar.date(byAdding: .day, value: -6, to: now)!, calendar: calendar)
        let monthStart = Solve.day(of: calendar.date(byAdding: .day, value: -29, to: now)!, calendar: calendar)

        // Runs after every solve: read just the columns the stats need, not whole solves.
        func result(_ row: Row) -> SolveResult {
            SolveResult(timeMs: row["time_ms"], penalty: Penalty(rawValue: row["penalty"]) ?? .none)
        }
        let (month, recent) = try writer.read { db in
            let month = try Row.fetchAll(db, sql: """
                SELECT date, time_ms, penalty FROM solves WHERE deleted_at IS NULL AND date >= ?
                """, arguments: [monthStart])
            let recent = try Row.fetchAll(db, sql: """
                SELECT time_ms, penalty FROM solves WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 100
                """)
            return (month, recent)
        }
        return StatsSummary(
            dated: month.map { (day: $0["date"], result: result($0)) },
            newestFirst: recent.map(result),
            today: today, weekStart: weekStart, monthStart: monthStart)
    }
}
