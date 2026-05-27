import AppKit
import Foundation
import Testing
@testable import emoji_picker

struct emoji_pickerTests {
    private let sampleEmojis = [
        Emoji(emoji: "😀", name: ["grinning face", "smile"]),
        Emoji(emoji: "🙂", name: ["slightly smiling face", "smiley"]),
        Emoji(emoji: "🔥", name: ["fire"]),
        Emoji(emoji: "👀", name: ["eyes"])
    ]

    @Test func exactMatchesRankAheadOfPrefixAndSubstringMatches() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )

        let results = service.results(for: "smile", limit: 10)

        #expect(results.map(\.emoji.emoji) == ["😀", "🙂"])
    }

    @Test func usageCountBreaksTiesWithinTheSameRank() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { emoji in
                emoji == "🙂" ? 8 : 1
            },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )

        let results = service.results(for: "smi", limit: 10)

        #expect(results.map(\.emoji.emoji) == ["🙂", "😀"])
    }

    @Test func emptySearchUsesMostUsedThenCuratedDefaults() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { emoji in
                emoji == "🔥" ? 5 : 0
            },
            mostUsedProvider: { _ in [("🔥", 5)] },
            isCustomProvider: { _ in false }
        )

        let results = service.results(for: "", limit: 4)

        #expect(results.first?.emoji.emoji == "🔥")
        #expect(results.count == 4)
    }

    @Test func duplicateEmojiValuesDoNotCrashSearchServiceInitialization() {
        let duplicatedEmojis = [
            Emoji(emoji: "😀", name: ["grinning face"]),
            Emoji(emoji: "😀", name: ["happy face"]),
            Emoji(emoji: "🔥", name: ["fire"])
        ]

        let service = EmojiSearchService(
            emojiProvider: { duplicatedEmojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )

        let results = service.results(for: "face", limit: 10)

        #expect(results.contains(where: { $0.emoji.emoji == "😀" }))
    }

    @Test @MainActor func pickerViewModelResetsSelectionWhenSearchChanges() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )
        let viewModel = EmojiPickerViewModel(searchService: service)

        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedIndex == 1)

        viewModel.searchText = "fire"

        #expect(viewModel.selectedIndex == 0)
        #expect(viewModel.selectedResult?.emoji.emoji == "🔥")
    }

    @Test @MainActor func pasteboardSnapshotRestoresStringContents() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("emoji-picker-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("after", forType: .string)

        snapshot.restore(to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "before")
    }

    @Test @MainActor func moveSelectionClampsAtBounds() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )
        let viewModel = EmojiPickerViewModel(searchService: service)

        viewModel.moveSelection(by: -5)
        #expect(viewModel.selectedIndex == 0)

        let lastIndex = viewModel.results.count - 1
        viewModel.moveSelection(by: 999)
        #expect(viewModel.selectedIndex == lastIndex)

        viewModel.moveSelection(by: 999)
        #expect(viewModel.selectedIndex == lastIndex)
    }

    @Test @MainActor func insertSelectedInvokesOnInsertWithCurrentSelection() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )
        let viewModel = EmojiPickerViewModel(searchService: service)

        var captured: EmojiSearchResult?
        viewModel.onInsert = { captured = $0 }

        viewModel.searchText = "fire"
        viewModel.insertSelected()

        #expect(captured?.emoji.emoji == "🔥")
    }

    @Test @MainActor func insertForwardsExplicitResultToOnInsert() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )
        let viewModel = EmojiPickerViewModel(searchService: service)

        var captured: EmojiSearchResult?
        viewModel.onInsert = { captured = $0 }

        let target = service.results(for: "eyes").first
        #expect(target?.emoji.emoji == "👀")

        if let target {
            viewModel.insert(target)
        }

        #expect(captured?.emoji.emoji == "👀")
    }

    @Test @MainActor func prepareForPresentationClearsSearchAndBumpsPresentationID() {
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )
        let viewModel = EmojiPickerViewModel(searchService: service)

        viewModel.searchText = "fire"
        let initialPresentationID = viewModel.presentationID

        viewModel.prepareForPresentation()

        #expect(viewModel.searchText == "")
        #expect(viewModel.presentationID != initialPresentationID)
        #expect(viewModel.selectedIndex == 0)
    }

    @Test func searchIsDiacriticAndCaseInsensitive() {
        let emojis = [
            Emoji(emoji: "☕", name: ["Café"]),
            Emoji(emoji: "🥖", name: ["Baguette"])
        ]
        let service = EmojiSearchService(
            emojiProvider: { emojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )

        let lowerNoDiacritic = service.results(for: "cafe", limit: 10)
        #expect(lowerNoDiacritic.map(\.emoji.emoji) == ["☕"])

        let upperWithDiacritic = service.results(for: "CAFÉ", limit: 10)
        #expect(upperWithDiacritic.map(\.emoji.emoji) == ["☕"])
    }

    @Test func searchRespectsLimitForNonEmptyQueries() {
        let emojis = (0..<10).map { index in
            Emoji(emoji: "E\(index)", name: ["match item \(index)"])
        }
        let service = EmojiSearchService(
            emojiProvider: { emojis },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { _ in false }
        )

        let results = service.results(for: "match", limit: 3)

        #expect(results.count == 3)
    }

    @Test func customEmojiIsSearchableByNameAndPasteText() {
        let custom = Emoji(emoji: ":super_smile:", name: ["super smile", ":super_smile:"])
        let service = EmojiSearchService(
            emojiProvider: { sampleEmojis + [custom] },
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] },
            isCustomProvider: { $0 == ":super_smile:" }
        )

        let byName = service.results(for: "super smile", limit: 10)
        #expect(byName.first?.emoji.emoji == ":super_smile:")
        #expect(byName.first?.isCustom == true)

        let byPasteText = service.results(for: ":super_smile:", limit: 10)
        #expect(byPasteText.first?.emoji.emoji == ":super_smile:")
    }

    @Test func statisticsDefaultSortHandlesDuplicateBundledEmojiValues() {
        let duplicatedBundled = [
            Emoji(emoji: "❤️‍🔥", name: ["heart on fire"]),
            Emoji(emoji: "❤️‍🔥", name: ["heart on fire variant"]),
            Emoji(emoji: "🔥", name: ["fire"])
        ]

        let sorted = EmojiStatisticsSorter.sorted(
            duplicatedBundled,
            mode: .default,
            bundledEmojis: duplicatedBundled,
            usageCount: { _ in 0 }
        )

        #expect(sorted.count == 3)
    }

    @Test func statisticsSortOrdersByUsage() {
        let emojis = [
            Emoji(emoji: "😀", name: ["grinning face"]),
            Emoji(emoji: "🔥", name: ["fire"]),
            Emoji(emoji: "👀", name: ["eyes"])
        ]

        let usageCounts = ["😀": 1, "🔥": 5, "👀": 3]

        let mostUsed = EmojiStatisticsSorter.sorted(
            emojis,
            mode: .mostUsed,
            bundledEmojis: emojis,
            usageCount: { usageCounts[$0, default: 0] }
        )
        #expect(mostUsed.map(\.emoji) == ["🔥", "👀", "😀"])

        let leastUsed = EmojiStatisticsSorter.sorted(
            emojis,
            mode: .leastUsed,
            bundledEmojis: emojis,
            usageCount: { usageCounts[$0, default: 0] }
        )
        #expect(leastUsed.map(\.emoji) == ["😀", "👀", "🔥"])
    }

    @Test @MainActor func customEmojiStoreAddsAndDeletesEntries() throws {
        let defaults = UserDefaults(suiteName: "emoji-picker-tests-\(UUID().uuidString)")!
        let store = CustomEmojiStore(
            bundledEmojis: sampleEmojis,
            userDefaults: defaults,
            storageKey: "customEmojis"
        )

        let added = try store.add(name: "super smile", pasteText: ":super_smile:")
        #expect(store.customEmojis.count == 1)
        #expect(store.isCustom(":super_smile:"))
        #expect(store.displayLetter(for: ":super_smile:") == "S")
        #expect(store.allEmojis.contains(where: { $0.emoji == ":super_smile:" }))

        store.delete(added)
        #expect(store.customEmojis.isEmpty)
        #expect(!store.isCustom(":super_smile:"))
    }
}
