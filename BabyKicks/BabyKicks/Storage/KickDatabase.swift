import Foundation
import SQLite3

enum KickDatabaseError: LocalizedError {
    case unavailable(String)
    case statement(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message), .statement(let message):
            message
        }
    }
}

final class KickDatabase: @unchecked Sendable {
    static let shared = KickDatabase()
    static let appGroupIdentifier = "group.com.photoncat.BabyKicks"

    private var database: OpaquePointer?
    private let lock = NSLock()

    private init() {
        do {
            try open()
            try createSchema()
        } catch {
            assertionFailure("Unable to open kicks database: \(error)")
        }
    }

    deinit {
        sqlite3_close(database)
    }

    func insert(timestamp: Date = .now) throws -> KickEvent {
        try locked {
            let sql = "INSERT INTO kick_events (timestamp) VALUES (?);"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw KickDatabaseError.statement(lastError)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, timestamp.timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw KickDatabaseError.statement(lastError)
            }
            return KickEvent(id: sqlite3_last_insert_rowid(database), timestamp: timestamp)
        }
    }

    func fetchAll() throws -> [KickEvent] {
        try locked {
            let sql = "SELECT id, timestamp FROM kick_events ORDER BY timestamp DESC;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw KickDatabaseError.statement(lastError)
            }
            defer { sqlite3_finalize(statement) }

            var events: [KickEvent] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                events.append(
                    KickEvent(
                        id: sqlite3_column_int64(statement, 0),
                        timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    )
                )
            }
            return events
        }
    }

    func count(from start: Date, through end: Date = .now) throws -> Int {
        try locked {
            let sql = """
            SELECT COUNT(*)
            FROM kick_events
            WHERE timestamp >= ? AND timestamp <= ?;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw KickDatabaseError.statement(lastError)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, end.timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw KickDatabaseError.statement(lastError)
            }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    func deleteAll() throws {
        try locked {
            guard sqlite3_exec(database, "DELETE FROM kick_events;", nil, nil, nil) == SQLITE_OK else {
                throw KickDatabaseError.statement(lastError)
            }
        }
    }

    private func open() throws {
        let fileManager = FileManager.default
        let directory: URL
        if let groupDirectory = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) {
            directory = groupDirectory
            try migrateLegacyDatabaseIfNeeded(to: directory)
        } else {
            directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "BabyKicks", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appending(path: "baby-kicks.sqlite")

        guard sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            throw KickDatabaseError.unavailable(lastError)
        }
    }

    private func migrateLegacyDatabaseIfNeeded(to directory: URL) throws {
        let fileManager = FileManager.default
        let destination = directory.appending(path: "baby-kicks.sqlite")
        guard !fileManager.fileExists(atPath: destination.path) else { return }

        let legacy = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "BabyKicks", directoryHint: .isDirectory)
            .appending(path: "baby-kicks.sqlite")
        guard fileManager.fileExists(atPath: legacy.path) else { return }
        try fileManager.copyItem(at: legacy, to: destination)
    }

    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS kick_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL
        );
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw KickDatabaseError.statement(lastError)
        }
    }

    private var lastError: String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }

    private func locked<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
