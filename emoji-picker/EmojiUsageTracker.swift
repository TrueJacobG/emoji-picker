import Foundation

class EmojiUsageTracker {
    static let shared = EmojiUsageTracker()
    
    private let userDefaults = UserDefaults.standard
    private let usageKey = "emojiUsageData"
    
    private init() {}
    
    func incrementUsage(for emoji: String) {
        var usageData = getUsageData()
        usageData[emoji, default: 0] += 1
        saveUsageData(usageData)
    }
    
    func getUsageCount(for emoji: String) -> Int {
        let usageData = getUsageData()
        return usageData[emoji] ?? 0
    }
    
    func getUsageData() -> [String: Int] {
        guard let data = userDefaults.dictionary(forKey: usageKey) as? [String: Int] else {
            return [:]
        }
        return data
    }
    
    func getMostUsedEmojis(limit: Int? = nil) -> [(emoji: String, count: Int)] {
        let usageData = getUsageData()
        let sorted = usageData.sorted { $0.value > $1.value }
        
        if let limit = limit {
            return Array(sorted.prefix(limit)).map { (emoji: $0.key, count: $0.value) }
        }
        return sorted.map { (emoji: $0.key, count: $0.value) }
    }
    
    func clearUsageData() {
        userDefaults.removeObject(forKey: usageKey)
    }
    
    private func saveUsageData(_ data: [String: Int]) {
        userDefaults.set(data, forKey: usageKey)
    }
}

