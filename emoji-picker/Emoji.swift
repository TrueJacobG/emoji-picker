import Foundation

struct Emoji: Identifiable, Codable, Hashable {
    let id = UUID()
    let emoji: String
    let name: [String]
    
    private enum CodingKeys: String, CodingKey {
        case emoji, name
    }
}

class EmojiProvider {
    
    static func loadEmojis(from filename: String) -> [Emoji] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            fatalError("Could not find \(filename).json in the app bundle. Make sure it's added to the project and the 'Copy Bundle Resources' build phase.")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load data from \(filename).json.")
        }
        
        do {
            let decoder = JSONDecoder()
            let emojis = try decoder.decode([Emoji].self, from: data)
            return emojis
        } catch {
            fatalError("Could not decode \(filename).json: \(error)")
        }
    }
}
