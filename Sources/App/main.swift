import Foundation
import PerfectNIO
import PerfectCRUD
import PerfectLogger

// Stop at once on a malformed PORT or DB_PORT.
Config.validate()

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

// PerfectCRUD prints the SQL it runs, and its own errors, to stdout. Send both to the log at
// debug level instead: the errors that matter reach the log anyway, from the route that hit them.
// Whitespace (CREATE TABLE spans lines) is collapsed so each event stays on one log line.
let crudToLog = CRUDLogDestination.custom { event in
    let message = event.msg.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    LogFile.debug("PerfectCRUD \(event.type): \(message)")
}
CRUDLogging.queryLogDestinations = [crudToLog]
CRUDLogging.errorLogDestinations = [crudToLog]

if !FileManager.default.fileExists(atPath: "\(Config.webroot)/index.html") {
    LogFile.warning("\(Config.webroot)/index.html not found; run from the package root or set WEBROOT")
}

// Connect once in the background so the posts table is created and a bad configuration shows
// up in the log right away, without delaying startup. If MySQL is unreachable the server still
// runs: database routes answer 503 until it is, and the first one that connects creates the table.
Task.detached {
    do {
        try await withDB { _ in }
    } catch {
        LogFile.warning("MySQL is not reachable yet; database routes will answer 503 until it is")
    }
}

// Request bodies are held in memory, so cap them well below Perfect-NIO's 10 MiB default.
// Larger requests are refused with 413 before their body is read.
let server = Server(routes: try allRoutes(), port: Config.port, maxRequestBodySize: 256 * 1024)
do {
    try await server.withServer { boundPort in
        LogFile.info("serving on http://localhost:\(boundPort)")
        // Serve until the process is stopped.
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3600 * 1_000_000_000)
        }
    }
} catch {
    LogFile.critical("could not start: \(error)")
    exit(1)
}

// ── Route composition ─────────────────────────────────────────────────────────

func allRoutes() throws -> Routes<HTTPRequest, HTTPOutput> {
    let web = try webRoutes()
    let api = try apiRoutes()
    return try root().dir(web, api)
}
