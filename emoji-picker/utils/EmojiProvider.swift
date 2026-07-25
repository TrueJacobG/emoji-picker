import Foundation
import OSLog

private let emojiProviderLogger = Logger(subsystem: "com.github.truejacobg.emoji-picker", category: "emojiProvider")

@MainActor
func loadEmojis(from filename: String) -> [Emoji] {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
        emojiProviderLogger.error("Could not find \(filename).json in the app bundle.")
        return []
    }

    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Emoji].self, from: data)
    } catch {
        emojiProviderLogger.error("Could not load or decode \(filename).json: \(error.localizedDescription, privacy: .public)")
        return []
    }
}
