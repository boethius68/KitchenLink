import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

// MARK: - SQLiteConnection
//
// Minimal, well-documented wrapper around a single SQLite database handle.
//
// Design notes (all claims verified against the SQLite C/C++ interface docs,
// https://www.sqlite.org/c3ref/intro.html, and the WAL mode docs,
// https://www.sqlite.org/wal.html):
//
//  1. We expose explicit transaction control (`BEGIN`/`COMMIT`/`ROLLBACK`)
//     rather than auto-commit heuristics. The EventStore performs the append +
//     outbox insert inside exactly ONE transaction; this type only provides the
//     mechanism, not the policy.
//  2. We do NOT use `SELECT ... FOR UPDATE`. SQLite locking is cooperative and
//     relies on `BEGIN IMMEDIATE` for write transactions. See
//     https://www.sqlite.org/lang_transaction.html and
//     https://www.sqlite.org/isolation.html.
// 3. WAL mode + `synchronous=FULL` + `fullfsync` is the documented way to get
//    the strongest durability SQLite offers without leaving WAL mode. We DO
//    NOT claim crash immunity beyond what these PRAGMAs + a successful commit
//    actually deliver; see EVENT_LOG_V2.md §Durability for the honest limits.
//    Refs:
//      - https://www.sqlite.org/pragma.html#pragma_synchronous
//      - https://www.sqlite.org/pragma.html#pragma_fullfsync
//      - https://www.sqlite.org/wal.html (§3 "Performance")
//
public final class SQLiteConnection: @unchecked Sendable {

    /// Errors that can be raised by this layer.
    public enum Error: Swift.Error, Equatable {
        case openFailed(String)          // sqlite_open message
        case execFailed(String)          // sqlite3_exec message
        case prepareFailed(String)       // sqlite3_prepare_v2 message
        case stepFailed(String)          // sqlite3_step message
        case bindFailed(String)          // sqlite3_bind_* message
        case transactionState(String)    // misuse of BEGIN/COMMIT
    }

    private var db: OpaquePointer?
    private let queue: DispatchQueue
    private let path: String

    /// Opens (or creates) the database at `path`.
    ///
    /// - Parameters:
    ///   - path: Filesystem path. Use `:memory:` for an ephemeral in-process DB
    ///     (used heavily by tests). Note: two `:memory:` databases opened in
    ///     separate handles are disjoint — see https://www.sqlite.org/inmemorydb.html.
    ///   - wal: When `true`, sets `journal_mode=WAL` (file-backed DBs only;
    ///     `:memory:` ignores this). WAL is recommended for the event log.
    /// - Throws: `Error.openFailed` if SQLite cannot open the file, or
    ///   `Error.execFailed` if a PRAGMA fails.
    public init(path: String, wal: Bool = true) throws {
        self.path = path
        self.queue = DispatchQueue(label: "kitchenlink.sqlite.\(UUID().uuidString)")

        var handle: OpaquePointer?
        // SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        // NOMUTEX: multi-thread mode; we serialize access via our own queue.
        // Ref: https://www.sqlite.org/c3ref/open.html
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        let openResult = sqlite3_open_v2(path, &handle, flags, nil)
        guard openResult == SQLITE_OK, let handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "open code \(openResult)"
            sqlite3_close(handle)
            throw Error.openFailed(msg)
        }
        self.db = handle

        // Foreign keys ON — the outbox references events.
        try exec("PRAGMA foreign_keys = ON;")

        if wal {
            // WAL only applies to file DBs; :memory: returns "memory".
            // We accept either result — the journal mode is best-effort.
            _ = try? scalar("PRAGMA journal_mode = WAL;")
        }

        // --- Documented durability policy ---------------------------------
        //
        // synchronous=FULL: "The EXTRA synchronous setting ... is the
        //   default ... and is the recommended choice." FULL ensures a keel-
        //   over after COMMIT is fully durable. Ref:
        //   https://www.sqlite.org/pragma.html#pragma_synchronous
        // fullfsync=ON: on macOS/iOS, forces F_FULLFSYNC for the strongest
        //   possible flush. Ref: https://www.sqlite.org/pragma.html#pragma_fullfsync
        //
        // These are PRAGMAs, not transactional DDL — they apply to this handle.
        try exec("PRAGMA synchronous = FULL;")
        try exec("PRAGMA fullfsync = ON;")
        // Keep WAL-checkpoint behavior explicit; the prototype relies on the
        // default PASSIVE checkpointing. See https://www.sqlite.org/wal.html.
        // busy_timeout: cooperate with a potential peer writer for up to 5s.
        try exec("PRAGMA busy_timeout = 5000;")
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: Execution primitives

    /// Runs `sql` with no result expected. Use for PRAGMAs and DDL.
    public func exec(_ sql: String) throws {
        try synced {
            var errMsg: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(self.db, sql, nil, nil, &errMsg)
            if rc != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "exec code \(rc)"
                sqlite3_free(errMsg)
                throw Error.execFailed(msg)
            }
        }
    }

    /// Prepares, binds, and steps a statement, then finalizes it.
    /// Returns the rowid of the last inserted row (or nil if none).
    @discardableResult
    public func execute(sql: String, params: [SQLValue] = []) throws -> Int64? {
        try synced {
            try self.executeLocked(sql: sql, params: params)
        }
    }

    private func executeLocked(sql: String, params: [SQLValue]) throws -> Int64? {
        var stmt: OpaquePointer?
        let prepRC = sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil)
        guard prepRC == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(self.db))
            throw Error.prepareFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }
        try bindAll(stmt: stmt, params: params)

        let stepRC = sqlite3_step(stmt)
        switch stepRC {
        case SQLITE_DONE:
            return sqlite3_last_insert_rowid(self.db)
        case SQLITE_ROW:
            // Callers needing rows use query(...). Here we just advance once.
            return sqlite3_last_insert_rowid(self.db)
        default:
            let msg = String(cString: sqlite3_errmsg(self.db))
            throw Error.stepFailed(msg)
        }
    }

    /// Runs `sql` (single SELECT returning a single value, e.g. a PRAGMA).
    public func scalar(_ sql: String) throws -> String? {
        try synced {
            var stmt: OpaquePointer?
            let rc = sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil)
            guard rc == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(self.db))
                throw Error.prepareFailed(msg)
            }
            defer { sqlite3_finalize(stmt) }
            let stepRC = sqlite3_step(stmt)
            guard stepRC == SQLITE_ROW else { return nil }
            let text = sqlite3_column_text(stmt, 0)
            return text.map { String(cString: $0) }
        }
    }

    /// Runs `sql` with `params` and maps each row via `mapper`.
    public func query<T>(sql: String,
                         params: [SQLValue] = [],
                         mapper: (StatementRow) -> T) throws -> [T] {
        try synced {
            var stmt: OpaquePointer?
            let rc = sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil)
            guard rc == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(self.db))
                throw Error.prepareFailed(msg)
            }
            defer { sqlite3_finalize(stmt) }
            try self.bindAll(stmt: stmt, params: params)

            var out: [T] = []
            while true {
                let stepRC = sqlite3_step(stmt)
                if stepRC == SQLITE_DONE { break }
                if stepRC != SQLITE_ROW {
                    let msg = String(cString: sqlite3_errmsg(self.db))
                    throw Error.stepFailed(msg)
                }
                out.append(mapper(StatementRow(stmt: stmt!)))
            }
            return out
        }
    }

    // MARK: Transaction control
    /// Begins a write transaction with an immediate reserved lock.
    ///
    /// `BEGIN IMMEDIATE` acquires the RESERVED lock up front, which means
    /// concurrent writers deterministically fail with SQLITE_BUSY (rather than
    /// with SQLITE_BUSY_SNAPSHOT under a deferred `BEGIN`). Ref:
    /// https://www.sqlite.org/lang_transaction.html (§"The optional
    /// transaction name is ignored").
    public func beginImmediate() throws {
        try exec("BEGIN IMMEDIATE;")
    }

    public func commit() throws {
        try exec("COMMIT;")
    }

    public func rollback() throws {
        try exec("ROLLBACK;")
    }

    /// Runs `body` inside a single `BEGIN IMMEDIATE ... COMMIT` transaction.
    ///
    /// This is the preferred way to group multiple statements (SELECT + UPDATE)
    /// into one atomic unit without reentrant locking: the whole body executes
    /// under ONE `queue.sync`, so the connection's serial queue is entered only
    /// once. On any thrown error, ROLLBACK is issued before propagating.
    ///
    /// `body` receives a `TX` context whose primitives operate WITHOUT
    /// re-entering the queue (they run inline). This is the only supported way
    /// to mix reads and writes inside a transaction.
    public func transaction<T>(_ body: (TX) throws -> T) throws -> T {
        try synced {
            try execLocked("BEGIN IMMEDIATE;")
            do {
                let tx = TX(connection: self)
                let result = try body(tx)
                try execLocked("COMMIT;")
                return result
            } catch {
                try? execLocked("ROLLBACK;")
                throw error
            }
        }
    }

    /// A transaction context. Its primitives execute inline (no queue re-entry)
    /// and must only be used inside `transaction(_:)`.
    public final class TX {
        fileprivate let connection: SQLiteConnection
        fileprivate init(connection: SQLiteConnection) { self.connection = connection }

        @discardableResult
        public func execute(sql: String, params: [SQLValue] = []) throws -> Int64? {
            try connection.executeLocked(sql: sql, params: params)
        }

        public func query<T>(sql: String,
                             params: [SQLValue] = [],
                             mapper: (StatementRow) -> T) throws -> [T] {
            try connection.queryLocked(sql: sql, params: params, mapper: mapper)
        }

        public func queryOne<T>(sql: String,
                                params: [SQLValue] = [],
                                mapper: (StatementRow) -> T) throws -> T? {
            try connection.queryLocked(sql: sql, params: params, mapper: mapper).first
        }
    }

    // Inline (no queue) variants used by TX. They assume the caller already
    // holds the queue via `synced`.
    fileprivate func execLocked(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(self.db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "exec code \(rc)"
            sqlite3_free(errMsg)
            throw Error.execFailed(msg)
        }
    }

    fileprivate func queryLocked<T>(sql: String,
                                    params: [SQLValue],
                                    mapper: (StatementRow) -> T) throws -> [T] {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(self.db))
            throw Error.prepareFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }
        try self.bindAll(stmt: stmt, params: params)

        var out: [T] = []
        while true {
            let stepRC = sqlite3_step(stmt)
            if stepRC == SQLITE_DONE { break }
            if stepRC != SQLITE_ROW {
                let msg = String(cString: sqlite3_errmsg(self.db))
                throw Error.stepFailed(msg)
            }
            out.append(mapper(StatementRow(stmt: stmt!)))
        }
        return out
    }

    // MARK: Binding helpers

    private func bindAll(stmt: OpaquePointer?, params: [SQLValue]) throws {
        // sqlite parameters are 1-indexed.
        for (index, value) in params.enumerated() {
            let i = Int32(index + 1)
            let rc: Int32
            switch value {
            case .null:
                rc = sqlite3_bind_null(stmt, i)
            case .integer(let v):
                rc = sqlite3_bind_int64(stmt, i, v)
            case .text(let s):
                // The Swift `String` is NOT a contiguous C string. We must
                // borrow a valid UTF-8 pointer for the duration of the bind
                // call. SQLITE_TRANSIENT (the -1 cast) makes SQLite copy the
                // bytes, so the pointer need not outlive this call.
                // Ref: https://www.sqlite.org/c3ref/bind_blob.html
                rc = s.withCString { ptr -> Int32 in
                    sqlite3_bind_text(stmt, i, ptr, -1,
                                      unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            case .blob(let d):
                // `Data` may not be contiguous; withUnsafeBytes gives a stable
                // raw buffer for the duration of the bind. SQLITE_TRANSIENT
                // (the -1 cast) makes SQLite copy the bytes, so the buffer
                // need not outlive this call.
                // Ref: https://www.sqlite.org/c3ref/bind_blob.html
                rc = d.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int32 in
                    sqlite3_bind_blob(stmt, i, buffer.baseAddress, Int32(buffer.count),
                                      unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            }
            guard rc == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(self.db))
                throw Error.bindFailed("bind \(i): \(msg)")
            }
        }
    }

    // MARK: Synchronization
    //
    // We use a serial dispatch queue to serialize all access to this handle
    // from Swift. SQLite was opened with SQLITE_OPEN_NOMUTEX, so the C library
    // itself is not re-entrant across threads for a single handle; the queue
    // is the safety net. (Ref: https://www.sqlite.org/threadsafe.html)
    private func synced<T>(_ body: () throws -> T) rethrows -> T {
        try queue.sync(execute: body)
    }
}

// MARK: - SQLValue

/// A bindable SQL value. Kept intentionally tiny; the event log stores its
/// payload as a BLOB (`[UInt8]`), which we model as `.blob(Data)`.
public enum SQLValue: Equatable, Sendable {
    case null
    case integer(Int64)
    case text(String)
    case blob(Data)
}

// MARK: - StatementRow

/// A cursor for reading columns from a stepped statement.
public struct StatementRow {
    let stmt: OpaquePointer

    public func int(_ index: Int32) -> Int64 {
        sqlite3_column_int64(stmt, index)
    }

    public func string(_ index: Int32) -> String? {
        guard let cstr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cstr)
    }

    public func data(_ index: Int32) -> Data? {
        let count = sqlite3_column_bytes(stmt, index)
        guard count > 0, let pointer = sqlite3_column_blob(stmt, index) else { return nil }
        return Data(bytes: pointer, count: Int(count))
    }

    public func bool(_ index: Int32) -> Bool {
        int(index) != 0
    }
}
