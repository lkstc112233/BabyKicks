import ActivityKit
import AppIntents
import Foundation
import SQLite3

struct RecordKickIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Record movement"
    static var description = IntentDescription("Records a baby movement without opening the app.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        try WidgetKickWriter.record()

        for activity in Activity<KickActivityAttributes>.activities {
            let count = try WidgetKickWriter.count(
                from: activity.attributes.startedAt,
                through: .now
            )
            let updatedState = KickActivityAttributes.ContentState(
                kickCount: count,
                lastKickAt: .now
            )
            await activity.update(
                ActivityContent(state: updatedState, staleDate: activity.attributes.endsAt)
            )
        }

        return .result()
    }
}

private enum WidgetKickWriter {
    static let appGroupIdentifier = "group.com.photoncat.BabyKicks"

    static func record(timestamp: Date = .now) throws {
        let database = try openDatabase()
        defer { sqlite3_close(database) }
        try createSchema(in: database)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "INSERT INTO kick_events (timestamp) VALUES (?);",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, timestamp.timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    static func count(from start: Date, through end: Date) throws -> Int {
        let database = try openDatabase()
        defer { sqlite3_close(database) }
        try createSchema(in: database)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "SELECT COUNT(*) FROM kick_events WHERE timestamp >= ? AND timestamp <= ?;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, end.timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw CocoaError(.fileReadUnknown)
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private static func openDatabase() throws -> OpaquePointer {
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let url = directory.appending(path: "baby-kicks.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw CocoaError(.fileReadUnknown)
        }
        guard let database else {
            throw CocoaError(.fileReadUnknown)
        }
        return database
    }

    private static func createSchema(in database: OpaquePointer) throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS kick_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL
        );
        """
        guard sqlite3_exec(database, schema, nil, nil, nil) == SQLITE_OK else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
