import Foundation
import PerfectNIO
import PerfectCRUD
import PerfectLogger

/// All routes under /api
///
/// GET    /api/health       — server health check, no database
/// GET    /api/posts        — list all posts, newest first
/// POST   /api/posts        — create a post  (body: {"title":"…","body":"…"})
/// GET    /api/posts/:id    — get one post by id
/// PUT    /api/posts/:id    — partial update  (body: {"title":"…"} or {"body":"…"} or both)
/// DELETE /api/posts/:id    — delete a post
///
/// POST and PUT take JSON only (Content-Type: application/json). Successful responses are
/// JSON. Errors are plain text with the matching status: 400 for invalid input, 404 for an
/// unknown id, 413 for an oversized body, 415 for a body that isn't JSON, 503 when no MySQL
/// connection can be opened, and 500 for anything else.
func apiRoutes() throws -> Routes<HTTPRequest, HTTPOutput> {

    // ── Health ────────────────────────────────────────────────────────────────

    let health = root().GET.api.health.map { _ -> HTTPOutput in
        try json(["status": "ok", "time": ISO8601DateFormatter().string(from: Date())])
    }

    // ── Posts: collection ─────────────────────────────────────────────────────

    let listPosts = root().GET.api.posts.map { _ -> HTTPOutput in
        let posts = try await withDB { db in
            // all() throws if the query fails. Iterating select() as a Sequence would
            // instead log the error and yield no rows, turning a failure into "[]".
            try db.table(Post.self).order(descending: \Post.createdAt, \Post.id).select().all()
        }
        return try json(posts)
    }

    // decode() reads the request body and passes it alongside the HTTPRequest. A body that
    // doesn't fit CreatePostRequest is answered 400 by Perfect-NIO.
    let createPost = root().POST.api.posts.requireJSON().decode(CreatePostRequest.self) { _, input -> HTTPOutput in
        let post = Post(
            id: UUID(),
            title: try validTitle(input.title),
            body: try validBody(input.body ?? ""),
            createdAt: Date()
        )
        try await withDB { db in _ = try db.table(Post.self).insert(post) }
        LogFile.info("created post id=\(post.id) title=\(logSafe(post.title))")
        return try json(post, status: .created)
    }

    // ── Posts: single resource ────────────────────────────────────────────────

    // wild() captures the next path segment as a String.
    let getPost = root().GET.api.posts.wild { _, segment -> HTTPOutput in
        let id = try postID(segment)
        guard let post = try await withDB({ db in
            try db.table(Post.self).where(\Post.id == id).first()
        }) else {
            throw notFound(id)
        }
        return try json(post)
    }

    // wild(name:) stores the captured segment in req.uriVariables so it's
    // still accessible after chaining decode().
    let updatePost = root().PUT.api.posts
        .wild(name: "id")
        .requireJSON()
        .decode(UpdatePostRequest.self) { req, input -> HTTPOutput in
            let id = try postID(req.uriVariables["id"] ?? "")
            let title = try input.title.map(validTitle)
            let body = try input.body.map(validBody)
            guard let post = try await withDB({ db -> Post? in
                let match = db.table(Post.self).where(\Post.id == id)
                guard var post = try match.first() else { return nil }
                // Write only the fields the request sent. Updating the whole row would put
                // back the other field as read above, undoing a concurrent update to it.
                switch (title, body) {
                case let (title?, body?):
                    post.title = title
                    post.body = body
                    try match.update(post, setKeys: \.title, \.body)
                case let (title?, nil):
                    post.title = title
                    try match.update(post, setKeys: \.title)
                case let (nil, body?):
                    post.body = body
                    try match.update(post, setKeys: \.body)
                case (nil, nil):
                    return post
                }
                // Read the row back, so the response shows what is stored now.
                return try match.first()
            }) else {
                throw notFound(id)
            }
            LogFile.info("updated post id=\(id)")
            return try json(post)
        }

    let deletePost = root().DELETE.api.posts.wild { _, segment -> HTTPOutput in
        let id = try postID(segment)
        let deleted = try await withDB { db -> Bool in
            // PerfectCRUD's typed delete() doesn't report how many rows it removed; the dynamic
            // API does, so one statement both deletes and tells us whether the post existed.
            // The table and key names come from the model, as the typed API would use them.
            let structure = try Post.CRUDTableStructure()
            let result = try db.mutate(DynamicMutation(
                action: .delete,
                table: structure.tableName,
                predicates: [DynamicPredicate(field: structure.primaryKeyName ?? "id",
                                              comparison: .equal, value: .string(id.uuidString))]
            ))
            return result.affectedRows > 0
        }
        guard deleted else { throw notFound(id) }
        LogFile.info("deleted post id=\(id)")
        return try json(["deleted": id])
    }

    return try root().dir(health, listPosts, createPost, getPost, updatePost, deletePost)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

extension Routes {
    /// Answers 415 unless the request says its body is JSON. Besides keeping the API honest,
    /// this stops another site's page from creating posts with a plain HTML form or a
    /// text/plain fetch, which browsers send cross-site without asking the server first.
    func requireJSON() -> Routes<InType, OutType> {
        request { output, req in
            let mediaType = req.contentType?
                .split(separator: ";").first?
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            guard mediaType == "application/json" else {
                throw ErrorOutput(status: .unsupportedMediaType, description: "Send the body as JSON with Content-Type: application/json.")
            }
            return output
        }
    }
}

/// JSON response with dates as ISO 8601 strings ("2026-10-15T17:04:05Z").
/// (Perfect-NIO's JSONOutput uses a default JSONEncoder, which writes dates as numbers.)
func json<T: Encodable>(_ value: T, status: HTTPResponseStatus = .ok) throws -> HTTPOutput {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return BytesOutput(
        head: HTTPHead(status: status, headers: HTTPHeaders([("Content-Type", "application/json")])),
        body: Array(try encoder.encode(value))
    )
}

/// User text for a log line: quoted, with everything outside printable ASCII escaped, so it
/// can't break the line or hide behind invisible or reordering characters.
private func logSafe(_ text: String) -> String {
    "\"" + text.unicodeScalars.map { $0.escaped(asASCII: true) }.joined() + "\""
}

/// Ids are UUIDs. Anything else can't name a post, so it is a 404 without a database query.
private func postID(_ segment: String) throws -> UUID {
    guard let id = UUID(uuidString: segment) else {
        throw ErrorOutput(status: .notFound, description: "No such post.")
    }
    return id
}

private func notFound(_ id: UUID) -> ErrorOutput {
    ErrorOutput(status: .notFound, description: "No post with id \(id).")
}

/// A title is one line of at most `PostLimits.titleLength` characters with something visible
/// in it. Control characters, line and paragraph separators, and the bidirectional controls
/// that can make text display in a different order than it is stored are refused. Other
/// invisible format characters are allowed (emoji sequences need the zero-width joiner), but
/// not on their own.
private func validTitle(_ title: String) throws -> String {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    try checkLength(title, name: "Title", characters: PostLimits.titleLength, codePoints: PostLimits.titleCodePoints)
    guard !title.unicodeScalars.contains(where: isRefusedInTitle) else {
        throw ErrorOutput(status: .badRequest, description: "Title must be a single line of plain text.")
    }
    guard title.unicodeScalars.contains(where: isVisible) else {
        throw ErrorOutput(status: .badRequest, description: "Title must not be empty.")
    }
    return title
}

private func validBody(_ body: String) throws -> String {
    try checkLength(body, name: "Body", characters: PostLimits.bodyLength, codePoints: PostLimits.bodyCodePoints)
    return body
}

/// Limits what a reader sees (characters) and, separately, the Unicode code points behind
/// them, so one character stacked with thousands of combining marks can't slip through.
private func checkLength(_ text: String, name: String, characters: Int, codePoints: Int) throws {
    guard text.count <= characters else {
        throw ErrorOutput(status: .badRequest, description: "\(name) must be at most \(grouped(characters)) characters.")
    }
    guard text.unicodeScalars.count <= codePoints else {
        throw ErrorOutput(status: .badRequest, description: "\(name) is too long (at most \(grouped(codePoints)) Unicode code points).")
    }
}

/// 20000 → "20,000", the same in every locale.
private func grouped(_ n: Int) -> String {
    var digits = String(n)
    var i = digits.endIndex
    while digits.distance(from: digits.startIndex, to: i) > 3 {
        i = digits.index(i, offsetBy: -3)
        digits.insert(",", at: i)
    }
    return digits
}

private func isRefusedInTitle(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x2028, 0x2029:                  // line and paragraph separators
        return true
    case 0x202A...0x202E, 0x2066...0x2069: // bidirectional embedding, override and isolate controls
        return true
    default:
        return scalar.properties.generalCategory == .control
    }
}

private func isVisible(_ scalar: Unicode.Scalar) -> Bool {
    !scalar.properties.isWhitespace && scalar.properties.generalCategory != .format
}
