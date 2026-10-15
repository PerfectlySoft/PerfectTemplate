import Foundation
import PerfectNIO
import PerfectCRUD
import PerfectMySQL
import PerfectLogger

typealias DB = Database<MySQLDatabaseConfiguration>

/// Runs `body` with its own MySQL connection and returns its result.
///
/// libmysqlclient calls block their thread, and a route handler runs on Swift's cooperative
/// thread pool, which must never block. So the whole unit of work (connect, make sure the
/// schema exists, run the queries) happens on a dispatch queue while the route awaits it.
///
/// Each call opens a new connection and closes it when `body` returns. That keeps the example
/// simple and recovers by itself when MySQL restarts. A busy service would reuse connections
/// with PerfectCRUD's `DatabaseConnectionPool` instead, and then has to deal with pooled
/// connections that went stale.
///
/// If no connection can be opened the route answers 503 Service Unavailable. Any other error
/// becomes a 500 whose details are logged by Perfect-NIO, not sent to the client.
func withDB<T: Sendable>(_ body: @escaping @Sendable (DB) throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        dbQueue.async {
            continuation.resume(with: Result {
                let db = try connect()
                try schema.ensure(db)
                return try body(db)
            })
        }
    }
}

private let dbQueue = DispatchQueue(label: "PerfectTemplate.db", attributes: .concurrent)

private func connect() throws -> DB {
    do {
        let config = try MySQLDatabaseConfiguration(
            database: Config.dbName,
            host: Config.dbHost,
            port: Config.dbPort,
            username: Config.dbUser,
            password: Config.dbPass
        )
        return Database(configuration: config)
    } catch {
        LogFile.error("cannot connect to MySQL at \(Config.dbHost):\(Config.dbPort): \(error)")
        throw ErrorOutput(status: .serviceUnavailable, description: "Database unavailable.")
    }
}

/// Creates the posts table the first time a connection succeeds. That is normally at startup,
/// but if MySQL was down then, the first request after it comes back does it instead.
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
