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
/// Successful responses are JSON. Errors are plain text with the matching status:
/// 400 for invalid input, 404 for an unknown id, 413 for an oversized body,
/// 503 when MySQL can't be reached, and 500 for anything else.
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
            try db.table(Post.self).order(descending: \Post.createdAt).select().all()
        }
        return try json(posts)
    }

    // decode() reads the JSON (or form) request body and passes it alongside the HTTPRequest.
    // A body that doesn't fit CreatePostRequest is answered 400 by Perfect-NIO.
    let createPost = root().POST.api.posts.decode(CreatePostRequest.self) { _, input -> HTTPOutput in
        let post = Post(
            id: UUID(),
            title: try validTitle(input.title),
            body: try validBody(input.body ?? ""),
            createdAt: Date()
        )
        try await withDB { db in _ = try db.table(Post.self).insert(post) }
        // String(reflecting:) quotes and escapes the title, so it stays on one log line.
        LogFile.info("created post id=\(post.id) title=\(String(reflecting: post.title))")
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
        .decode(UpdatePostRequest.self) { req, input -> HTTPOutput in
            let id = try postID(req.uriVariables["id"] ?? "")
            let title = try input.title.map(validTitle)
            let body = try input.body.map(validBody)
            guard let post = try await withDB({ db -> Post? in
                let posts = db.table(Post.self)
                guard var post = try posts.where(\Post.id == id).first() else { return nil }
                if let title { post.title = title }
                if let body { post.body = body }
                try posts.where(\Post.id == id).update(post)
                return post
            }) else {
                throw notFound(id)
            }
            LogFile.info("updated post id=\(id)")
            return try json(post)
        }

    let deletePost = root().DELETE.api.posts.wild { _, segment -> HTTPOutput in
        let id = try postID(segment)
        let deleted = try await withDB { db -> Bool in
            let match = db.table(Post.self).where(\Post.id == id)
            guard try match.count() > 0 else { return false }
            try match.delete()
            return true
        }
        guard deleted else { throw notFound(id) }
        LogFile.info("deleted post id=\(id)")
        return try json(["deleted": id])
    }

    return try root().dir(health, listPosts, createPost, getPost, updatePost, deletePost)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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

/// A title is one non-empty line of at most `PostLimits.titleLength` characters.
private func validTitle(_ title: String) throws -> String {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
        throw ErrorOutput(status: .badRequest, description: "Title must not be empty.")
    }
    guard title.count <= PostLimits.titleLength else {
        throw ErrorOutput(status: .badRequest, description: "Title must be at most \(PostLimits.titleLength) characters.")
    }
    guard !title.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
        throw ErrorOutput(status: .badRequest, description: "Title must be a single line.")
    }
    return title
}

private func validBody(_ body: String) throws -> String {
    guard body.count <= PostLimits.bodyLength else {
        throw ErrorOutput(status: .badRequest, description: "Body must be at most \(PostLimits.bodyLength) characters.")
    }
    return body
}
