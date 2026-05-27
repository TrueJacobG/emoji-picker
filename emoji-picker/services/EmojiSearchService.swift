import Foundation

struct EmojiSearchResult: Identifiable, Equatable {
    let emoji: Emoji
    let matchedAlias: String
    let usageCount: Int
    let isCustom: Bool

    var id: String { emoji.id }
    var primaryName: String { emoji.name.first ?? emoji.emoji }
    var aliasSummary: String {
        emoji.name.prefix(3).joined(separator: ", ")
    }
}

final class EmojiSearchService {
    private let emojiProvider: () -> [Emoji]
    private let usageCountProvider: (String) -> Int
    private let mostUsedProvider: (Int?) -> [(emoji: String, count: Int)]
    private let isCustomProvider: (String) -> Bool
    private let curatedDefaults = [
        "😀", "😂", "😍", "🥲", "🤔", "🙌", "🔥", "✅",
        "🎉", "🙏", "👀", "🤝", "💡", "🚀", "❤️", "👍",
        "👎", "✨", "📌", "⚠️", "🐛", "📦", "🍎", "💻"
    ]

    init(
        emojiProvider: @escaping () -> [Emoji] = { EmojiProvider.loadEmojis(from: "emoji2") },
        usageCountProvider: @escaping (String) -> Int = { EmojiUsageTracker.shared.getUsageCount(for: $0) },
        mostUsedProvider: @escaping (Int?) -> [(emoji: String, count: Int)] = { EmojiUsageTracker.shared.getMostUsedEmojis(limit: $0) },
        isCustomProvider: @escaping (String) -> Bool = { _ in false }
    ) {
        self.emojiProvider = emojiProvider
        self.usageCountProvider = usageCountProvider
        self.mostUsedProvider = mostUsedProvider
        self.isCustomProvider = isCustomProvider
    }

    func results(for query: String, limit: Int = 40) -> [EmojiSearchResult] {
        let emojis = emojiProvider()
        let emojiByValue = emojis.reduce(into: [String: Emoji]()) { partialResult, emoji in
            if partialResult[emoji.emoji] == nil {
                partialResult[emoji.emoji] = emoji
            }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return defaultResults(from: emojis, emojiByValue: emojiByValue, limit: limit)
        }

        let normalizedQuery = normalize(trimmedQuery)

        return emojis.compactMap { emoji in
            bestMatch(for: emoji, query: normalizedQuery)
        }
        .sorted { lhs, rhs in
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }

            if lhs.result.usageCount != rhs.result.usageCount {
                return lhs.result.usageCount > rhs.result.usageCount
            }

            if lhs.aliasLength != rhs.aliasLength {
                return lhs.aliasLength < rhs.aliasLength
            }

            return lhs.result.primaryName.localizedCaseInsensitiveCompare(rhs.result.primaryName) == .orderedAscending
        }
        .prefix(limit)
        .map(\.result)
    }

    private func bestMatch(for emoji: Emoji, query: String) -> (result: EmojiSearchResult, rank: Int, aliasLength: Int)? {
        let usageCount = usageCountProvider(emoji.emoji)

        let candidates = emoji.name.compactMap { alias -> (rank: Int, alias: String)? in
            let normalizedAlias = normalize(alias)

            if normalizedAlias == query {
                return (0, alias)
            }

            if normalizedAlias.hasPrefix(query) {
                return (1, alias)
            }

            if normalizedAlias.contains(query) {
                return (2, alias)
            }

            return nil
        }

        guard let bestCandidate = candidates.sorted(by: {
            if $0.rank != $1.rank {
                return $0.rank < $1.rank
            }

            return $0.alias.count < $1.alias.count
        }).first else {
            return nil
        }

        return (
            result: EmojiSearchResult(
                emoji: emoji,
                matchedAlias: bestCandidate.alias,
                usageCount: usageCount,
                isCustom: isCustomProvider(emoji.emoji)
            ),
            rank: bestCandidate.rank,
            aliasLength: bestCandidate.alias.count
        )
    }

    private func defaultResults(from emojis: [Emoji], emojiByValue: [String: Emoji], limit: Int) -> [EmojiSearchResult] {
        var results: [EmojiSearchResult] = []
        var seen = Set<String>()

        for entry in mostUsedProvider(nil) {
            guard seen.insert(entry.emoji).inserted, let emoji = emojiByValue[entry.emoji] else {
                continue
            }

            results.append(
                EmojiSearchResult(
                    emoji: emoji,
                    matchedAlias: emoji.name.first ?? emoji.emoji,
                    usageCount: entry.count,
                    isCustom: isCustomProvider(emoji.emoji)
                )
            )
        }

        for emojiValue in curatedDefaults {
            guard seen.insert(emojiValue).inserted, let emoji = emojiByValue[emojiValue] else {
                continue
            }

            results.append(
                EmojiSearchResult(
                    emoji: emoji,
                    matchedAlias: emoji.name.first ?? emoji.emoji,
                    usageCount: usageCountProvider(emojiValue),
                    isCustom: isCustomProvider(emojiValue)
                )
            )
        }

        if results.count < limit {
            let alphabeticFallback = emojis.sorted {
                ($0.name.first ?? $0.emoji).localizedCaseInsensitiveCompare($1.name.first ?? $1.emoji) == .orderedAscending
            }

            for emoji in alphabeticFallback where seen.insert(emoji.emoji).inserted {
                results.append(
                    EmojiSearchResult(
                        emoji: emoji,
                        matchedAlias: emoji.name.first ?? emoji.emoji,
                        usageCount: usageCountProvider(emoji.emoji),
                        isCustom: isCustomProvider(emoji.emoji)
                    )
                )
            }
        }

        return Array(results.prefix(limit))
    }

    private func normalize(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
