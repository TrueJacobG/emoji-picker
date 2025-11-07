import Foundation

struct Emoji: Identifiable, Codable, Hashable {
    let id = UUID()
    let emoji: String
    let name: [String]
    
    private enum CodingKeys: String, CodingKey {
        case emoji, name
    }
}

