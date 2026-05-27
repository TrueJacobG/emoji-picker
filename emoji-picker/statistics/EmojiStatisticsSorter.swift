import Foundation

enum StatisticsSortMode: CaseIterable {
    case `default`
    case mostUsed
    case leastUsed
}

enum EmojiStatisticsSorter {
    static func sorted(
        _ emojis: [Emoji],
        mode: StatisticsSortMode,
        bundledEmojis: [Emoji],
        usageCount: (String) -> Int
    ) -> [Emoji] {
        switch mode {
        case .default:
            var bundledOrder: [String: Int] = [:]
            for (index, emoji) in bundledEmojis.enumerated() where bundledOrder[emoji.emoji] == nil {
                bundledOrder[emoji.emoji] = index
            }

            return emojis.sorted { lhs, rhs in
                let lhsOrder = bundledOrder[lhs.emoji] ?? Int.max
                let rhsOrder = bundledOrder[rhs.emoji] ?? Int.max

                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }

                return primaryName(for: lhs).localizedCaseInsensitiveCompare(primaryName(for: rhs)) == .orderedAscending
            }
        case .mostUsed:
            return emojis.sorted { lhs, rhs in
                let lhsCount = usageCount(lhs.emoji)
                let rhsCount = usageCount(rhs.emoji)

                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }

                return primaryName(for: lhs).localizedCaseInsensitiveCompare(primaryName(for: rhs)) == .orderedAscending
            }
        case .leastUsed:
            return emojis.sorted { lhs, rhs in
                let lhsCount = usageCount(lhs.emoji)
                let rhsCount = usageCount(rhs.emoji)

                if lhsCount != rhsCount {
                    return lhsCount < rhsCount
                }

                return primaryName(for: lhs).localizedCaseInsensitiveCompare(primaryName(for: rhs)) == .orderedAscending
            }
        }
    }

    private static func primaryName(for emoji: Emoji) -> String {
        emoji.name.first ?? emoji.emoji
    }
}
