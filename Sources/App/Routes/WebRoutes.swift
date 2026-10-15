import PerfectNIO

/// GET /          → serves webroot/index.html
/// GET /posts     → serves webroot/posts.html (CRUD UI)
/// GET /static/** → serves any file under webroot/static/
///
/// Each also answers HEAD: Perfect-NIO sends the headers GET would, without the body.
///
/// Perfect-NIO answers 400 to any request path with a ".." segment (raw or percent-encoded)
/// before routing, so the trailing path can't climb out of webroot/static.
func webRoutes() throws -> Routes<HTTPRequest, HTTPOutput> {
    let index = root().method(.GET, .HEAD).map { _ -> HTTPOutput in
        try FileOutput(localPath: "\(Config.webroot)/index.html")
    }
    let postsPage = root().method(.GET, .HEAD).path("posts").map { _ -> HTTPOutput in
        try FileOutput(localPath: "\(Config.webroot)/posts.html")
    }
    let staticFiles = root().method(.GET, .HEAD).path("static").trailing { _, path -> HTTPOutput in
        try FileOutput(localPath: "\(Config.webroot)/static/\(path)")
    }
    return try root().dir(index, postsPage, staticFiles)
}
