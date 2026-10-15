import Foundation
import NIOPosix
import PerfectNIO
import PerfectCRUD
import PerfectMySQL
import PerfectLogger

typealias DB = Database<MySQLDatabaseConfiguration>

/// Runs `body` with its own MySQL connection and returns its result.
///
/// libmysqlclient calls block their thread, and a route handler runs on Swift's cooperative
/// thread pool, which must never block. So the whole unit of work (connect, make sure the
/// schema exists, run the queries) runs on `dbThreads`, a fixed pool of threads used only for
/// the database, while the route awaits it. When MySQL is slow or a table is locked, at most
/// that many requests wait inside MySQL and the rest queue for a thread; the health check,
/// the pages and everything else keep answering.
///
/// Each call opens a new connection and closes it when `body` returns. That keeps the example
/// simple and recovers by itself when MySQL restarts. A busy service would reuse connections
/// with PerfectCRUD's `DatabaseConnectionPool` instead, and then has to deal with pooled
/// connections that went stale.
///
/// The route answers 503 Service Unavailable when no connection can be opened within
/// `connectTimeout` seconds (or one failed in the last `retryDelay` seconds), and when MySQL
/// gives up on a statement that waited too long for a lock or ran too long. Any other error
/// becomes a 500 whose details are logged by Perfect-NIO, not sent to the client.
func withDB<T: Sendable>(_ body: @escaping @Sendable (DB) throws -> T) async throws -> T {
    try await dbThreads.runIfActive {
        let db = try connect()
        do {
            try schema.ensure(db)
            return try body(db)
        } catch where isBusyError(error) {
            LogFile.warning("MySQL gave up on a statement: \(error)")
            throw ErrorOutput(status: .serviceUnavailable, description: "Database busy.")
        }
    }
}

/// Threads that run database work. Also the most MySQL connections the app opens at once.
private let dbThreads: NIOThreadPool = {
    let pool = NIOThreadPool(numberOfThreads: 16)
    pool.start()
    return pool
}()

/// Seconds to wait for MySQL to accept a connection.
private let connectTimeout = 5
/// Seconds a single read from or write to MySQL may take before the client gives up.
private let ioTimeout = 30
/// Seconds MySQL itself lets a statement wait for a lock, or a SELECT run. Shorter than
/// `ioTimeout`, so MySQL abandons the statement before the client stops waiting for it: a
/// request that fails has not written anything, and the server isn't left holding sessions.
private let statementTimeout = 20
/// Whether MySQL abandoned the statement because of the limits above: ER_LOCK_WAIT_TIMEOUT
/// (1205) or ER_QUERY_TIMEOUT (3024). Perfect-MySQL's MySQLCRUDError carries only the server's
/// message, and the connection's error code is already reset when it reaches us, so this
/// matches MySQL's (English) message text for those two errors.
private func isBusyError(_ error: any Error) -> Bool {
    let text = String(describing: error)
    return text.contains("Lock wait timeout exceeded")
        || text.contains("maximum statement execution time exceeded")
}

private func connect() throws -> DB {
    try outage.check()
    let mysql = MySQL()
    mysql.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4")
    mysql.setOption(.MYSQL_OPT_CONNECT_TIMEOUT, connectTimeout)
    mysql.setOption(.MYSQL_OPT_READ_TIMEOUT, ioTimeout)
    mysql.setOption(.MYSQL_OPT_WRITE_TIMEOUT, ioTimeout)
    // Runs on every new connection. lock_wait_timeout covers table and metadata locks
    // (LOCK TABLES, DDL), innodb_lock_wait_timeout row locks, and max_execution_time (in
    // milliseconds, MySQL 5.7.8 and later) caps SELECTs.
    mysql.setOption(.MYSQL_INIT_COMMAND, """
        SET SESSION lock_wait_timeout = \(statementTimeout), \
        innodb_lock_wait_timeout = \(statementTimeout), \
        max_execution_time = \(statementTimeout * 1000)
        """)
    guard mysql.connect(host: Config.dbHost, user: Config.dbUser, password: Config.dbPass,
                        db: Config.dbName, port: UInt32(Config.dbPort)) else {
        outage.failed(mysql.errorMessage())
        throw ErrorOutput(status: .serviceUnavailable, description: "Database unavailable.")
    }
    outage.connected()
    return Database(configuration: MySQLDatabaseConfiguration(connection: mysql))
}

/// Seconds after a failed connection during which requests get 503 at once, instead of each
/// waiting up to `connectTimeout` for MySQL again.
private let retryDelay: TimeInterval = 2

/// Remembers the last failed connection, for the fast 503 above, and logs failures at most
/// once every 10 seconds so an outage under load doesn't write a line per request.
private let outage = Outage()

private final class Outage: @unchecked Sendable {
    private let lock = NSLock()
    private var lastFailure: Date?
    private var lastLogged: Date?
    private var suppressed = 0

    func check() throws {
        lock.lock()
        defer { lock.unlock() }
        if let lastFailure, Date().timeIntervalSince(lastFailure) < retryDelay {
            suppressed += 1
            throw ErrorOutput(status: .serviceUnavailable, description: "Database unavailable.")
        }
    }

    func connected() {
        lock.lock()
        defer { lock.unlock() }
        lastFailure = nil
    }

    func failed(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        lastFailure = now
        if let lastLogged, now.timeIntervalSince(lastLogged) < 10 {
            suppressed += 1
            return
        }
        let more = suppressed > 0 ? " (\(suppressed) more failed requests since the last report)" : ""
        LogFile.error("cannot connect to MySQL at \(Config.dbHost):\(Config.dbPort): \(message)\(more)")
        lastLogged = now
        suppressed = 0
    }
}

/// Creates the posts table the first time a connection succeeds. That is normally at startup,
/// but if MySQL was down then, the first request after it comes back does it instead.
///
/// `ready` is remembered for the life of the process, so if the table is dropped while the
/// app is running, restart the app to create it again.
private let schema = Schema()

private final class Schema: @unchecked Sendable {
    private let lock = NSLock()
    private var ready = false

    func ensure(_ db: DB) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !ready else { return }
        try db.create(Post.self, policy: .shallow)
        ready = true
        LogFile.info("database schema ready")
    }
}
