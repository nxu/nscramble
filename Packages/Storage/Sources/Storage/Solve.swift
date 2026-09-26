import Foundation
import GRDB
import StatsKit

/// One timed solve.
public struct Solve: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// When the solve finished.
    public var createdAt: Date
    /// Local calendar day of `createdAt`, `YYYY-MM-DD`.
    public var date: String
    /// Raw time, without the +2 penalty.
    public var timeMs: Int
    /// Scramble in WCA notation.
    public var scramble: String
    public var penalty: Penalty
    public var updatedAt: Date
    public var deletedAt: Date?

    public var isDeleted: Bool { deletedAt != nil }

    /// `YYYY-MM-DD` in the current time zone.
    static func day(of date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public var result: SolveResult {
        SolveResult(timeMs: timeMs, penalty: penalty)
    }
}

extension Solve: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "solves"

    public enum Columns {
        public static let createdAt = Column("created_at")
        public static let deletedAt = Column("deleted_at")
    }

    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    public static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .millisecondsSince1970
    }

    public static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .millisecondsSince1970
    }

    public static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy {
        .lowercaseString
    }

    static var active: QueryInterfaceRequest<Solve> {
        all().filter(Columns.deletedAt == nil)
    }
}
