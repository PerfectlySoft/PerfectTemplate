import PerfectNIO

/// GET /         → serves webroot/index.html
/// GET /posts     → serves webroot/posts.html (CRUD UI)
/// GET /static/** → serves any file under webroot/static/
func webRoutes() throws -> Routes<HTTPRequest, HTTPOutput> {
    let index = root().GET.map { _ -> HTTPOutput in
        try FileOutput(localPath: "webroot/index.html")
    }
    let postsPage = root().GET.path("posts").map { _ -> HTTPOutput in
        try FileOutput(localPath: "webroot/posts.html")
    }
    let staticFiles = root().GET.path("static").trailing { _, path -> HTTPOutput in
        try FileOutput(localPath: "webroot/static/\(path)")
    }
    return try root().dir(index, postsPage, staticFiles)
}
