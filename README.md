# PerfectTemplate

A reference application demonstrating this ecosystem end to end. It's a small blog-style "Posts"
CRUD web app that wires together **Perfect-NIO**, **Perfect-CRUD**, **Perfect-MySQL**, and
**Perfect-Logger** — JSON API, MySQL persistence, structured logging, and a static browser UI, all
in one place. Nothing else here depends on this repo; it exists to demonstrate the four libraries
working together and as a starting point for new apps built on them.

The pre-Swift-6 version of this package is preserved on the [`legacy`](../../tree/legacy) branch.

## Requirements

- **Swift tools version:** 6.2
- **Platform:** macOS 12+ (`.macOS(.v12)`) — no Linux or other platform target is currently declared
- A reachable **MySQL** server (the app starts even if MySQL is unreachable, but database-backed routes will error until a connection is available)

## Dependencies

| Package | Products used |
|---|---|
| [Perfect-NIO](https://github.com/PerfectlySoft/Perfect-NIO) | `PerfectNIO`, `PerfectNIOCRUD` |
| [Perfect-CRUD](https://github.com/PerfectlySoft/Perfect-CRUD) | `PerfectCRUD` |
| [Perfect-MySQL](https://github.com/PerfectlySoft/Perfect-MySQL) | `PerfectMySQL` |
| [Perfect-Logger](https://github.com/PerfectlySoft/Perfect-Logger) | `PerfectLogger` |

## What it does

- **`main.swift`** bootstraps `PerfectLogger` (console + rolling file), runs schema setup for the `posts` MySQL table (non-fatal if MySQL is down), builds routes, and starts a `PerfectNIO` `Server` on `Config.port`.
- **API routes** (`Sources/App/Routes/APIRoutes.swift`), backed by a MySQL-persisted `Post` model via PerfectCRUD:
  - `GET /api/health` — health check, no database
  - `GET /api/posts` — list all posts
  - `POST /api/posts` — create a post
  - `GET /api/posts/:id` — get one post
  - `PUT /api/posts/:id` — partial update
  - `DELETE /api/posts/:id` — delete a post
  - `GET /api/dbsetup` — re-run schema setup
- **Web routes** (`Sources/App/Routes/WebRoutes.swift`) serve `webroot/index.html`, `webroot/posts.html` (a browser CRUD UI), and `webroot/static/**`.

## Configuration

Everything is environment-variable driven with sane defaults (see `Sources/App/Config.swift`):

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `9191` | HTTP server port |
| `DB_HOST` | `127.0.0.1` | MySQL host |
| `DB_NAME` | `perfect_template` | MySQL database name |
| `DB_USER` | `root` | MySQL user |
| `DB_PASS` | *(empty)* | MySQL password |
| `LOG_FILE` | `./perfect-template.log` | Rolling log file path |
| `LOG_LEVEL` | `info` | `debug` / `info` / `warning` / `error` / `critical` |

## Running

```sh
swift run
```

Or with overrides:

```sh
PORT=9090 DB_NAME=myapp DB_USER=root LOG_LEVEL=debug swift run
```

Then visit `http://localhost:9191` (or your configured `PORT`) for the browser UI, or hit the `/api/*` routes directly.

## Status

This is a small, currently-maintained reference app — not an abandoned scaffold. It's kept in sync with the current APIs of its four dependencies (Perfect-NIO, Perfect-CRUD, Perfect-MySQL, Perfect-Logger) as they evolve.
