import Foundation
import GRDB
import StatsKit

extension AppDatabase {
    /// Today, last 7 and last 30 days (each including today, by local calendar day), plus ao5/ao12/ao100.
    public func statsSummary(now: Date = Date(), calendar: Calendar = .current) throws -> StatsSummary {
        let today = Solve.day(of: now, calendar: calendar)
        let weekStart = Solve.day(of: calendar.date(byAdding: .day, value: -6, to: now)!, calendar: calendar)
        let monthStart = Solve.day(of: calendar.date(byAdding: .day, value: -29, to: now)!, calendar: calendar)

        let (month, recent) = try writer.read { db in
            let month = try Solve.active.filter(Solve.Columns.date >= monthStart).fetchAll(db)
            let recent = try Solve.active.order(Solve.Columns.createdAt.desc).limit(100).fetchAll(db)
            return (month, recent)
        }
        return StatsSummary(
            dated: month.map { (day: $0.date, result: $0.result) },
            newestFirst: recent.map(\.result),
            today: today, weekStart: weekStart, monthStart: monthStart)
    }
}
