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
/// If no connection can be opened within `connectTimeout` seconds the route answers 503
/// Service Unavailable. Any other error, including a query that runs past `ioTimeout`, becomes
/// a 500 whose details are logged by Perfect-NIO, not sent to the client.
func withDB<T: Sendable>(_ body: @escaping @Sendable (DB) throws -> T) async throws -> T {
    try await dbThreads.runIfActive {
        let db = try connect()
        try schema.ensure(db)
        return try body(db)
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
/// Seconds a single read from or write to MySQL may take (libmysqlclient may retry a read).
private let ioTimeout = 30

private func connect() throws -> DB {
    let mysql = MySQL()
    mysql.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4")
    mysql.setOption(.MYSQL_OPT_CONNECT_TIMEOUT, connectTimeout)
    mysql.setOption(.MYSQL_OPT_READ_TIMEOUT, ioTimeout)
    mysql.setOption(.MYSQL_OPT_WRITE_TIMEOUT, ioTimeout)
    guard mysql.connect(host: Config.dbHost, user: Config.dbUser, password: Config.dbPass,
                        db: Config.dbName, port: UInt32(Config.dbPort)) else {
        connectFailures.log(mysql.errorMessage())
        throw ErrorOutput(status: .serviceUnavailable, description: "Database unavailable.")
    }
    return Database(configuration: MySQLDatabaseConfiguration(connection: mysql))
}

/// Logs connection failures at most once every 10 seconds, so an outage under load doesn't
/// write a line per request.
private let connectFailures = ConnectFailureLog()

private final class ConnectFailureLog: @unchecked Sendable {
    private let lock = NSLock()
    private var lastLogged: Date?
    private var suppressed = 0

    func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if let lastLogged, now.timeIntervalSince(lastLogged) < 10 {
            suppressed += 1
            return
        }
        let more = suppressed > 0 ? " (\(suppressed) more since the last report)" : ""
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
