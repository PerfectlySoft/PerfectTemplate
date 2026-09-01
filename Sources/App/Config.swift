import Foundation
import PerfectLogger

/// App configuration sourced from environment variables with sane defaults.
/// Set these before launching or pass them via the shell:
///   PORT=9090 DB_NAME=myapp DB_USER=root LOG_LEVEL=debug swift run
enum Config {
    static let port   = env("PORT").flatMap(Int.init) ?? 9191
    static let dbHost = env("DB_HOST")      ?? "127.0.0.1"
    static let dbName = env("DB_NAME")      ?? "perfect_template"
    static let dbUser = env("DB_USER")      ?? "root"
    static let dbPass = env("DB_PASS")      ?? ""

    /// Path the file log handler appends to. Default: ./perfect-template.log
    static let logFile = env("LOG_FILE") ?? "./perfect-template.log"

    /// Minimum log level for all handlers. Set LOG_LEVEL=debug for verbose output.
    static let logLevel: LogPriority = {
        switch (env("LOG_LEVEL") ?? "info").lowercased() {
        case "debug":            return .debug
        case "warning", "warn":  return .warning
        case "error":            return .error
        case "critical":         return .critical
        default:                 return .info
        }
    }()

    private static func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}
