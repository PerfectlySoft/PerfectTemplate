import PerfectCRUD
import PerfectMySQL
import PerfectLogger

/// Creates a new database connection per call. Safe to call from any thread or task.
func makeDB() throws -> Database<MySQLDatabaseConfiguration> {
    let config = try MySQLDatabaseConfiguration(
        database: Config.dbName,
        host: Config.dbHost,
        username: Config.dbUser,
        password: Config.dbPass
    )
    return Database(configuration: config)
}

/// Creates the posts table if it doesn't exist. Called once at startup.
func setupSchema() -> String {
    do {
        let db = try makeDB()
        try db.create(Post.self, policy: .shallow)
        LogFile.info("database schema ready")
        return "Database schema ready."
    } catch {
        LogFile.error("schema setup failed — \(error); server will start, database routes will fail until MySQL is reachable")
        return "Warning: schema setup failed — \(error)"
    }
}
