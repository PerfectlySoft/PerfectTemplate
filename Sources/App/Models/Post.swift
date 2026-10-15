import Foundation

/// A row in the `posts` table. PerfectCRUD maps the properties to columns: `id` is the
/// primary key (VARCHAR(36) in MySQL) and `createdAt` is a DATETIME, stored to the second.
struct Post: Codable, Sendable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
}

/// Body of `POST /api/posts`.
struct CreatePostRequest: Codable, Sendable {
    var title: String
    var body: String?
}

/// Body of `PUT /api/posts/:id`. Fields left out keep their current values.
struct UpdatePostRequest: Codable, Sendable {
    var title: String?
    var body: String?
}

/// Input limits. The server also refuses request bodies over `maxRequestBodySize` (see main.swift).
enum PostLimits {
    /// Characters, as a reader counts them.
    static let titleLength = 200
    static let bodyLength = 20_000
    /// Unicode code points. Generous for real text (an emoji family is 7), but bounded.
    static let titleCodePoints = 2_000
    static let bodyCodePoints = 100_000
}
