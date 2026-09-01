import Foundation
import PerfectNIO
import PerfectLogger

// Configure logging first: console + a rolling file, at the configured level.
// Every LogFile.* call (and any swift-log Logger inside the Perfect libraries)
// flows through these handlers. Bootstrap must run exactly once, before any log.
PerfectLogger.bootstrap(
    console: true,
    file: Config.logFile,
    level: Config.logLevel.level
)
LogFile.info("PerfectTemplate starting (log level \(Config.logLevel), file \(Config.logFile))")

// Set up the database schema on startup. If MySQL is unreachable the server
// still starts — database routes will return errors until a connection is available.
let _ = setupSchema()

let routes = try allRoutes()
LogFile.info("serving on http://localhost:\(Config.port)")
try await Server(routes: routes, port: Config.port).run()

// ── Route composition ─────────────────────────────────────────────────────────

func allRoutes() throws -> Routes<HTTPRequest, HTTPOutput> {
    let web = try webRoutes()
    let api = try apiRoutes()
    return try root().dir(web, api)
}
