import Foundation
import PerfectNIO
import PerfectCRUD
import PerfectMySQL
import PerfectLogger

/// All routes under /api
///
/// GET    /api/health       — server health check, no database
/// GET    /api/posts        — list all posts
/// POST   /api/posts        — create a post  (body: {"title":"…","body":"…"})
/// GET    /api/posts/:id    — get one post by id
/// PUT    /api/posts/:id    — partial update  (body: {"title":"…"} or {"body":"…"} or both)
/// DELETE /api/posts/:id    — delete a post
func apiRoutes() throws -> Routes<HTTPRequest, HTTPOutput> {

    // ── Health ────────────────────────────────────────────────────────────────

    let health = root().GET.api.health.map { _ -> HTTPOutput in
        let body: [String: String] = [
            "status": "ok",
            "time": ISO8601DateFormatter().string(from: Date()),
        ]
        return try JSONOutput(body)
    }

    // ── Posts: collection ─────────────────────────────────────────────────────

    let listPosts = root().GET.api.posts.map { _ -> HTTPOutput in
        let posts = try makeDB().table(Post.self).select().map { $0 }
        return try JSONOutput(posts)
    }

    // decode() reads the JSON request body and passes it alongside the HTTPRequest.
    let createPost = root().POST.api.posts.decode(CreatePostRequest.self) { _, input -> HTTPOutput in
        let post = Post(
            id: UUID().uuidString,
            title: input.title,
            body: input.body,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        // The returned event id correlates every subsequent log line for this request.
        let eid = LogFile.info("creating post \"\(post.title)\"")
        do {
            try makeDB().table(Post.self).insert(post)
        } catch {
            LogFile.error("failed to create post: \(error)", eventid: eid)
            throw error
        }
        LogFile.info("created post id=\(post.id)", eventid: eid)
        // Return 201 Created with the new post.
        return try JSONOutput(post, head: HTTPHead(status: .created, headers: HTTPHeaders()))
    }

    // ── Posts: single resource ────────────────────────────────────────────────

    // wild() captures the next path segment as a String.
    let getPost = root().GET.api.posts.wild { _, id -> HTTPOutput in
        let db = try makeDB()
        guard let post = try db.table(Post.self).where(\Post.id == id).select().map({ $0 }).first else {
            LogFile.warning("post not found id=\(id)")
            throw ErrorOutput(status: .notFound, description: "No post with id: \(id)")
        }
        return try JSONOutput(post)
    }

    // wild(name:) stores the captured segment in req.uriVariables so it's
    // still accessible after chaining decode().
    let updatePost = root().PUT.api.posts
        .wild(name: "id")
        .decode(UpdatePostRequest.self) { req, input -> HTTPOutput in
            guard let id = req.uriVariables["id"] else {
                throw ErrorOutput(status: .badRequest, description: "Missing post id")
            }
            let db = try makeDB()
            guard var post = try db.table(Post.self).where(\Post.id == id).select().map({ $0 }).first else {
                throw ErrorOutput(status: .notFound, description: "No post with id: \(id)")
            }
            if let title = input.title { post.title = title }
            if let body = input.body { post.body = body }
            try db.table(Post.self).where(\Post.id == id).update(post)
            return try JSONOutput(post)
        }

    let deletePost = root().DELETE.api.posts.wild { _, id -> HTTPOutput in
        do {
            try makeDB().table(Post.self).where(\Post.id == id).delete()
        } catch {
            LogFile.error("failed to delete post id=\(id): \(error)")
            throw error
        }
        LogFile.info("deleted post id=\(id)")
        return try JSONOutput(["deleted": id])
    }
    let dbSetup = root().GET.api.dbsetup.map { _ -> HTTPOutput in
        let schemaResult = setupSchema()
        
        return try JSONOutput([schemaResult])
    }
    
    return try root().dir(health, listPosts, createPost, getPost, updatePost, deletePost, dbSetup)
}
