import Foundation

struct Comment: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var authorId: String = ""
    var author: String = "Partner"
    var authorAvatarURL: String? = nil
    var text: String
    var createdAt: Date = Date()
}
