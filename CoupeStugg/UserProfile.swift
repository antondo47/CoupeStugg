import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var avatarURL: String?
    var updatedAt: Date
}
