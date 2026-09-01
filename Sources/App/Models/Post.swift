import Foundation

struct Post: Codable, Sendable {
    var id: String
    var title: String
    var body: String
    var createdAt: String
}

struct CreatePostRequest: Codable, Sendable {
    var title: String
    var body: String
}

struct UpdatePostRequest: Codable, Sendable {
    var title: String?
    var body: String?
}
