import Foundation
import OSLog

@MainActor
final class EmojiUsageTracker {
    static let shared = EmojiUsageTracker()

    private static let logger = Logger(subsystem: "com.github.truejacobg.emoji-picker", category: "usageTracker")

    private let userDefaults = UserDefaults.standard
    private let usageKey = "emojiUsageData"

    private var cachedUsageData: [String: Int]?
    private var isCacheLoaded = false

    private init() {}

    func incrementUsage(for emoji: String) {
        var usageData = usageData()
        usageData[emoji, default: 0] += 1
        cachedUsageData = usageData
        saveUsageData(usageData)
    }

    func getUsageCount(for emoji: String) -> Int {
        usageData()[emoji] ?? 0
    }

    func getUsageData() -> [String: Int] {
        usageData()
    }

    func getMostUsedEmojis(limit: Int? = nil) -> [(emoji: String, count: Int)] {
        let data = usageData()
        let sorted = data.sorted { $0.value > $1.value }

        if let limit {
            return Array(sorted.prefix(limit)).map { (emoji: $0.key, count: $0.value) }
        }
        return sorted.map { (emoji: $0.key, count: $0.value) }
    }

    func clearUsageData() {
        userDefaults.removeObject(forKey: usageKey)
        cachedUsageData = [:]
    }

    private func usageData() -> [String: Int] {
        if let cached = cachedUsageData {
            return cached
        }

        let data = (userDefaults.dictionary(forKey: usageKey) as? [String: Int]) ?? [:]
        cachedUsageData = data
        isCacheLoaded = true
        return data
    }

    private func saveUsageData(_ data: [String: Int]) {
        userDefaults.set(data, forKey: usageKey)
    }
}
