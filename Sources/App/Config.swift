import Foundation
import PerfectLogger

/// App configuration, read from environment variables.
///
/// The database defaults match the README's quick start, which runs MySQL in a container
/// published on host port 13306. That port is deliberately not MySQL's usual 3306, so the
/// example never quietly connects to (and creates tables in) some other MySQL server
/// already running on this machine. Point it anywhere else with the DB_* variables:
///
///     DB_HOST=db.internal DB_PORT=3306 DB_USER=app DB_PASS=secret swift run
enum Config {
    /// HTTP port the server listens on.
    static let port    = portNumber("PORT", default: 9191)
    static let dbHost  = env("DB_HOST") ?? "127.0.0.1"
    static let dbPort  = portNumber("DB_PORT", default: 13306)
    static let dbName  = env("DB_NAME") ?? "perfect_template"
    static let dbUser  = env("DB_USER") ?? "perfect"
    static let dbPass  = env("DB_PASS") ?? "perfect"

    /// Directory holding index.html, posts.html and static/. Relative paths are resolved
    /// against the working directory, so run from the package root or set an absolute path.
    static let webroot = env("WEBROOT") ?? "webroot"

    /// Path the file log handler appends to.
    static let logFile = env("LOG_FILE") ?? "./perfect-template.log"

    /// Minimum log level for all handlers. Set LOG_LEVEL=debug for verbose output,
    /// including the SQL PerfectCRUD runs.
    static let logLevel: LogPriority = {
        switch (env("LOG_LEVEL") ?? "info").lowercased() {
        case "debug":            return .debug
        case "warning", "warn":  return .warning
        case "error":            return .error
        case "critical":         return .critical
        default:                 return .info
        }
    }()

    /// Reads every setting once, so a bad value stops the app at launch with a clear message
    /// instead of surfacing later.
    static func validate() {
        _ = (port, dbPort)
    }

    private static func env(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else { return nil }
        return value
    }

    private static func portNumber(_ key: String, default defaultValue: Int) -> Int {
        guard let value = env(key) else { return defaultValue }
        guard let port = Int(value), (1...65535).contains(port) else {
            FileHandle.standardError.write(Data("\(key) must be a port number from 1 to 65535, not \(String(reflecting: value)).\n".utf8))
            exit(1)
        }
        return port
    }
}
