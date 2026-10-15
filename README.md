# PerfectTemplate

A reference application for the Perfect Swift 6 libraries. It's a small blog-style "Posts"
CRUD web app that wires together **Perfect-NIO**, **Perfect-CRUD**, **Perfect-MySQL**, and
**Perfect-Logger**: a JSON API, MySQL persistence, structured logging, and a static browser UI.
Copy it as the starting point for a new app built on them.

The pre-Swift-6 version of this package is preserved on the [`legacy`](https://github.com/PerfectlySoft/PerfectTemplate/tree/legacy) branch.

## Requirements

- Swift 6.2 or later (swift-tools-version 6.2)
- macOS 12 or later, or Linux (CI builds on Ubuntu 24.04)
- The MySQL client library and `pkg-config`:
  - macOS: `brew install mysql-client pkgconf`, then
    `export PKG_CONFIG_PATH="$(brew --prefix mysql-client)/lib/pkgconfig"` (the formula is keg-only)
  - Debian/Ubuntu: `apt-get install libmysqlclient-dev pkg-config`
- A MySQL server (8.x). The quick start runs one in a container.

On macOS the linker may warn that Homebrew's `libmysqlclient` was built for a newer macOS than
the package's macOS 12 deployment target. The app still builds and runs on the machine it was
built on.

## Dependencies

| Package | Version | Products used |
|---|---|---|
| [Perfect-NIO](https://github.com/PerfectlySoft/Perfect-NIO) | 0.1.0 | `PerfectNIO` |
| [Perfect-CRUD](https://github.com/PerfectlySoft/Perfect-CRUD) | 3.1.0 | `PerfectCRUD` |
| [Perfect-MySQL](https://github.com/PerfectlySoft/Perfect-MySQL) | 4.0.0 | `PerfectMySQL` |
| [Perfect-Logger](https://github.com/PerfectlySoft/Perfect-Logger) | 4.0.0 | `PerfectLogger` |
| [swift-nio](https://github.com/apple/swift-nio) | 2.65.0 | `NIOPosix` (already used by Perfect-NIO) |

Versions are minimums (`from:`), so `swift package update` picks up compatible releases.

## Quick start

Start MySQL in a container. It is published on host port **13306**, not 3306, so it can't
collide with a MySQL server you already run; the app's defaults point at it.

```sh
docker run -d --name perfect-template-mysql -p 13306:3306 \
    -e MYSQL_ROOT_PASSWORD=change-me \
    -e MYSQL_DATABASE=perfect_template \
    -e MYSQL_USER=perfect -e MYSQL_PASSWORD=perfect \
    mysql:8.4
```

(With Apple's `container` tool, the same command works with `container run`.) Give MySQL a few
seconds to initialise, then build and run the app from the package root:

```sh
swift run
```

Open <http://localhost:9191> for the overview page and <http://localhost:9191/posts> for the
browser UI, or use the API:

```sh
curl http://localhost:9191/api/health
curl -X POST http://localhost:9191/api/posts \
     -H "Content-Type: application/json" \
     -d '{"title":"Hello","body":"World"}'
curl http://localhost:9191/api/posts
```

The `Post` table is created on the first successful connection. If MySQL
isn't reachable the server starts anyway: database routes answer 503 until it is. The app
remembers that the table exists, so if you drop it while the app runs, restart the app.

## Configuration

Everything comes from environment variables (see `Sources/App/Config.swift`). The database
defaults match the quick start container above.

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `9191` | HTTP port, 1–65535 (the server listens on all interfaces) |
| `DB_HOST` | `127.0.0.1` | MySQL host |
| `DB_PORT` | `13306` | MySQL port, 1–65535. Set `3306` for a server on the standard port |
| `DB_NAME` | `perfect_template` | MySQL database; it must exist |
| `DB_USER` | `perfect` | MySQL user |
| `DB_PASS` | `perfect` | MySQL password |
| `WEBROOT` | `webroot` | Directory with the HTML pages and `static/`, relative to the working directory |
| `LOG_FILE` | `./perfect-template.log` | File the log is appended to |
| `LOG_LEVEL` | `info` | `debug`, `info`, `warning`, `error` or `critical`. `debug` also logs the SQL PerfectCRUD runs |

A `PORT` or `DB_PORT` that isn't a whole number from 1 to 65535 stops the app at launch with a
message saying so.

For example, against an existing server:

```sh
DB_HOST=db.internal DB_PORT=3306 DB_USER=app DB_PASS=secret swift run
```

Run from the package root (or set `WEBROOT` to an absolute path), since the pages are read
from disk at request time. In Xcode, set the scheme's working directory to the package folder.

## Routes

| Method | Path | Description |
|---|---|---|
| `GET`, `HEAD` | `/` | Overview page (`webroot/index.html`) |
| `GET`, `HEAD` | `/posts` | Browser UI for the API (`webroot/posts.html`) |
| `GET`, `HEAD` | `/static/**` | Files under `webroot/static/` |
| `GET` | `/api/health` | Health check; doesn't touch the database |
| `GET` | `/api/posts` | All posts, newest first |
| `POST` | `/api/posts` | Create a post: `{"title": "…", "body": "…"}` (`body` optional) |
| `GET` | `/api/posts/:id` | One post |
| `PUT` | `/api/posts/:id` | Update `title`, `body`, or both |
| `DELETE` | `/api/posts/:id` | Delete a post |

`POST` and `PUT` take a JSON body sent with `Content-Type: application/json`. A `PUT` writes
only the fields it sends, so two clients updating different fields don't undo each other.

A post looks like this; `id` is a UUID and `createdAt` an ISO 8601 time in UTC:

```json
{"id":"9C3A0D2E-0B7C-4C1E-9E55-2F1F7A0B6E1D","title":"Hello","body":"World","createdAt":"2026-10-15T16:10:51Z"}
```

Errors are plain text with the status code saying what went wrong:

| Status | When |
|---|---|
| 400 | The JSON doesn't fit the route (for example, no `title` on create); the title is empty or only invisible characters, over 200 characters, or contains a control character, line or paragraph separator, or bidirectional control; or the body is over 20,000 characters. Also any request path with a `..` segment |
| 404 | No post with that id (or the id isn't a UUID), or no such page or file |
| 413 | The request body is over 256 KiB |
| 415 | `POST` or `PUT` without `Content-Type: application/json` |
| 503 | No connection to MySQL could be opened within 5 seconds |
| 500 | Anything else, such as a query that fails or takes over 30 seconds to answer; the details go to the log, not the client |

## How it's put together

- `main.swift` checks the configuration, bootstraps PerfectLogger (console and file), sends
  PerfectCRUD's own logging to it at debug level, connects to MySQL in the background so the
  schema exists, and starts the Perfect-NIO `Server` with a 256 KiB request body limit.
- `DB.swift` has `withDB {}`, which opens a MySQL connection, makes sure the table exists, and
  runs the work on a pool of 16 threads used only for the database (a swift-nio
  `NIOThreadPool`). Blocking libmysqlclient calls stay off Swift's cooperative thread pool, and
  when MySQL is slow or a table is locked, at most 16 requests wait on it while the health
  check, pages and other requests keep answering. Connections time out after 5 seconds and
  reads and writes after 30. It opens a connection per request; for a busy service, look at
  PerfectCRUD's `DatabaseConnectionPool`.
- `Routes/APIRoutes.swift` is the JSON API, with input validation and error mapping.
- `Routes/WebRoutes.swift` serves the pages and static files. Perfect-NIO refuses any request
  path with a `..` segment before routing, so static paths can't leave `webroot/static`.
- `Models/Post.swift` is the PerfectCRUD model and request types.

## Checking a running server

`Scripts/smoke-test.sh` drives every API route against a running server (create, list, get,
update, delete, and the error cases). `Scripts/smoke-test.sh --no-db` checks a server that has no
database: health and pages answer 200 and `/api/posts` answers 503. CI runs both.

## License

Apache 2.0; see [LICENSE](LICENSE) ([中文](LICENSE.zh_CN)).
