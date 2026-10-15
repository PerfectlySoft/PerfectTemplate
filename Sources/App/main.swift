import Foundation
import PerfectNIO
import PerfectLogger

// Configure logging first: console + a file, at the configured level.
// Every LogFile.* call (and any swift-log Logger inside the Perfect libraries)
// flows through these handlers. Bootstrap must run exactly once, before any log.
PerfectLogger.bootstrap(
    console: true,
    file: Config.logFile,
    level: Config.logLevel.level
)
LogFile.info("PerfectTemplate starting (log level \(Config.logLevel), file \(Config.logFile))")
LogFile.info("database \(Config.dbName) on \(Config.dbHost):\(Config.dbPort) as \(Config.dbUser)")

// Connect once at startup so the posts table is created and a bad configuration shows up
// in the log right away. If MySQL is unreachable the server still starts: database routes
// answer 503 until it is, and the first one that connects creates the table.
do {
    try await withDB { _ in }
} catch {
    LogFile.warning("MySQL is not reachable yet; database routes will answer 503 until it is")
}

let routes = try allRoutes()
LogFile.info("serving on http://localhost:\(Config.port)")
// Request bodies are held in memory, so cap them well below Perfect-NIO's 10 MiB default.
// Larger requests are refused with 413 before their body is read.
try await Server(routes: routes, port: Config.port, maxRequestBodySize: 256 * 1024).run()

// ── Route composition ─────────────────────────────────────────────────────────

func allRoutes() throws -> Routes<HTTPRequest, HTTPOutput> {
    let web = try webRoutes()
    let api = try apiRoutes()
    return try root().dir(web, api)
}
