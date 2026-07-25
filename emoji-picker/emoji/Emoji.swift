import Foundation

struct Emoji: Identifiable, Codable, Hashable {
    let emoji: String
    let name: [String]

    var id: String { emoji }
}
