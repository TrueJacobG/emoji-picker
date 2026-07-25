import AppKit
import Foundation
import Testing
@testable import emoji_picker

@MainActor
final class emoji_pickerTests {
    private let sampleEmojis = [
        Emoji(emoji: "😀", name: ["grinning face", "smile"]),
        Emoji(emoji: "🙂", name: ["slightly smiling face", "smiley"]),
        Emoji(emoji: "🔥", name: ["fire"]),
        Emoji(emoji: "👀", name: ["eyes"])
    ]

    private func makeService(
        emojis: [Emoji],
        usageCount: @escaping (String) -> Int = { _ in 0 },
        mostUsed: [(emoji: String, count: Int)] = [],
        isCustom: @escaping (String) -> Bool = { _ in false }
    ) -> EmojiSearchService {
        EmojiSearchService(
            emojiProvider: { emojis },
            usageCountProvider: usageCount,
            mostUsedProvider: { _ in mostUsed },
            isCustomProvider: isCustom
        )
    }

    @Test func exactMatchesRankAheadOfPrefixAndSubstringMatches() {
        let service = makeService(emojis: sampleEmojis)

        let results = service.results(for: "smile", limit: 10)

        #expect(results.map(\.emoji.emoji) == ["😀", "🙂"])
    }

    @Test func usageCountBreaksTiesWithinTheSameRank() {
        let service = makeService(
            emojis: sampleEmojis,
            usageCount: { emoji in emoji == "🙂" ? 8 : 1 }
        )

        let results = service.results(for: "smi", limit: 10)

        #expect(results.map(\.emoji.emoji) == ["🙂", "😀"])
    }

    @Test func emptySearchUsesMostUsedThenCuratedDefaults() {
        let service = makeService(
            emojis: sampleEmojis,
            usageCount: { emoji in emoji == "🔥" ? 5 : 0 },
            mostUsed: [("🔥", 5)]
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

        let service = makeService(emojis: duplicatedEmojis)

        let results = service.results(for: "face", limit: 10)

        #expect(results.contains(where: { $0.emoji.emoji == "😀" }))
    }

    @Test func pickerViewModelResetsSelectionWhenSearchChanges() {
        let service = makeService(emojis: sampleEmojis)
        let viewModel = EmojiPickerViewModel(searchService: service)

        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedIndex == 1)

        viewModel.searchText = "fire"

        #expect(viewModel.selectedIndex == 0)
        #expect(viewModel.selectedResult?.emoji.emoji == "🔥")
    }

    @Test func pasteboardSnapshotRestoresStringContents() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("emoji-picker-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("after", forType: .string)

        snapshot.restore(to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "before")
    }

    @Test func moveSelectionClampsAtBounds() {
        let service = makeService(emojis: sampleEmojis)
        let viewModel = EmojiPickerViewModel(searchService: service)

        viewModel.moveSelection(by: -5)
        #expect(viewModel.selectedIndex == 0)

        let lastIndex = viewModel.results.count - 1
        viewModel.moveSelection(by: 999)
        #expect(viewModel.selectedIndex == lastIndex)

        viewModel.moveSelection(by: 999)
        #expect(viewModel.selectedIndex == lastIndex)
    }

    @Test func insertSelectedInvokesOnInsertWithCurrentSelection() {
        let service = makeService(emojis: sampleEmojis)
        let viewModel = EmojiPickerViewModel(searchService: service)

        var captured: EmojiSearchResult?
        viewModel.onInsert = { captured = $0 }

        viewModel.searchText = "fire"
        viewModel.insertSelected()

        #expect(captured?.emoji.emoji == "🔥")
    }

    @Test func insertForwardsExplicitResultToOnInsert() {
        let service = makeService(emojis: sampleEmojis)
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

    @Test func prepareForPresentationClearsSearchAndBumpsPresentationID() {
        let service = makeService(emojis: sampleEmojis)
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
        let service = makeService(emojis: emojis)

        let lowerNoDiacritic = service.results(for: "cafe", limit: 10)
        #expect(lowerNoDiacritic.map(\.emoji.emoji) == ["☕"])

        let upperWithDiacritic = service.results(for: "CAFÉ", limit: 10)
        #expect(upperWithDiacritic.map(\.emoji.emoji) == ["☕"])
    }

    @Test func searchRespectsLimitForNonEmptyQueries() {
        let emojis = (0..<10).map { index in
            Emoji(emoji: "E\(index)", name: ["match item \(index)"])
        }
        let service = makeService(emojis: emojis)

        let results = service.results(for: "match", limit: 3)

        #expect(results.count == 3)
    }

    @Test func customEmojiIsSearchableByNameAndPasteText() {
        let custom = Emoji(emoji: ":super_smile:", name: ["super smile", ":super_smile:"])
        let service = makeService(
            emojis: sampleEmojis + [custom],
            isCustom: { $0 == ":super_smile:" }
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

    @Test func customEmojiStoreAddsAndDeletesEntries() throws {
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

    @Test func replaceTextAtCursorInsertsEmoji() {
        let result = replaceTextAtSelection(
            currentText: "hello world",
            selectionLocation: 5,
            selectionLength: 0,
            replacement: "😀"
        )
        #expect(result.updatedText == "hello😀 world")
        #expect(result.newCursorLocation == 7)
    }

    @Test func replaceTextWithSelectionReplacesRange() {
        let result = replaceTextAtSelection(
            currentText: "hello world",
            selectionLocation: 0,
            selectionLength: 5,
            replacement: "🔥"
        )
        #expect(result.updatedText == "🔥 world")
        #expect(result.newCursorLocation == ("🔥" as NSString).length)
    }

    @Test func replaceTextSelectionAtEndAppends() {
        let result = replaceTextAtSelection(
            currentText: "hello",
            selectionLocation: 5,
            selectionLength: 0,
            replacement: "👍"
        )
        #expect(result.updatedText == "hello👍")
        #expect(result.newCursorLocation == ("hello" as NSString).length + ("👍" as NSString).length)
    }

    @Test func replaceTextInvalidSelectionClampsToEnd() {
        let result = replaceTextAtSelection(
            currentText: "hi",
            selectionLocation: Int.max,
            selectionLength: 0,
            replacement: "❤️"
        )
        #expect(result.updatedText == "hi❤️")
        #expect(result.newCursorLocation == 4)
    }

    @Test func replaceTextSelectionOutOfRangeClampsToEnd() {
        let result = replaceTextAtSelection(
            currentText: "ab",
            selectionLocation: 1,
            selectionLength: 5,
            replacement: "✨"
        )
        #expect(result.updatedText == "ab✨")
        #expect(result.newCursorLocation == 3)
    }

    @Test func replaceTextNSNotFoundLocationAppends() {
        let result = replaceTextAtSelection(
            currentText: "test",
            selectionLocation: NSNotFound,
            selectionLength: 0,
            replacement: "🎉"
        )
        #expect(result.updatedText == "test🎉")
        #expect(result.newCursorLocation == ("test🎉" as NSString).length)
    }

    @Test func replaceTextEmptyCurrentTextInsertsEmoji() {
        let result = replaceTextAtSelection(
            currentText: "",
            selectionLocation: 0,
            selectionLength: 0,
            replacement: "😀"
        )
        #expect(result.updatedText == "😀")
        #expect(result.newCursorLocation == ("😀" as NSString).length)
    }

    @Test func replaceTextMultiByteEmojiCharacters() {
        let result = replaceTextAtSelection(
            currentText: "abc",
            selectionLocation: 0,
            selectionLength: 0,
            replacement: "🇵🇱"
        )
        #expect(result.updatedText == "🇵🇱abc")
        #expect(result.newCursorLocation == ("🇵🇱" as NSString).length)
    }

    @Test func replaceTextReplaceAll() {
        let result = replaceTextAtSelection(
            currentText: "hello",
            selectionLocation: 0,
            selectionLength: 5,
            replacement: "👋"
        )
        #expect(result.updatedText == "👋")
        #expect(result.newCursorLocation == ("👋" as NSString).length)
    }

    @Test func appendTextToEmptyString() {
        let result = appendText(currentText: "", text: "😀")
        #expect(result.updatedText == "😀")
        #expect(result.newCursorLocation == ("😀" as NSString).length)
    }

    @Test func appendTextToExistingString() {
        let result = appendText(currentText: "hello", text: "🔥")
        #expect(result.updatedText == "hello🔥")
        #expect(result.newCursorLocation == ("hello🔥" as NSString).length)
    }

    @Test func appendTextMultipleEmojis() {
        let result = appendText(currentText: "😀", text: "🔥👍")
        #expect(result.updatedText == "😀🔥👍")
        #expect(result.newCursorLocation == ("😀🔥👍" as NSString).length)
    }

    @Test func replaceThenReplaceChain() {
        let first = replaceTextAtSelection(
            currentText: "hello world",
            selectionLocation: 5,
            selectionLength: 0,
            replacement: "😀"
        )
        #expect(first.updatedText == "hello😀 world")
        #expect(first.newCursorLocation == ("hello😀" as NSString).length)

        let second = replaceTextAtSelection(
            currentText: first.updatedText,
            selectionLocation: 0,
            selectionLength: 3,
            replacement: "👋"
        )
        #expect(second.updatedText == "👋lo😀 world")
        #expect(second.newCursorLocation == ("👋" as NSString).length)
    }

    // MARK: - Regression tests for fixed bugs

    @Test func emojiStatisticsSorterDoesNotCrashOnEmptyNameArray() {
        // Regression: EmojiCellWithStats used to force-unwrap emoji.name[0];
        // the sorter and views must tolerate an empty name array.
        let emojis = [
            Emoji(emoji: "🔥", name: ["fire"]),
            Emoji(emoji: "💥", name: [])
        ]

        let mostUsed = EmojiStatisticsSorter.sorted(
            emojis,
            mode: .mostUsed,
            bundledEmojis: emojis,
            usageCount: { _ in 0 }
        )
        #expect(mostUsed.count == 2)

        let defaultSorted = EmojiStatisticsSorter.sorted(
            emojis,
            mode: .default,
            bundledEmojis: emojis,
            usageCount: { _ in 0 }
        )
        #expect(defaultSorted.count == 2)
    }

    @Test func pickerViewModelResetsSelectionToZeroOnEmptyResults() {
        // Regression: refreshResults had `results.isEmpty ? 0 : 0` (both branches 0).
        // After fixing, an empty result set must leave selectedIndex at 0 and
        // selectedResult nil without crashing.
        let service = makeService(emojis: sampleEmojis)
        let viewModel = EmojiPickerViewModel(searchService: service)

        viewModel.searchText = "zzzznope"
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedIndex == 0)
        #expect(viewModel.selectedResult == nil)

        // moveSelection on empty results must not move and not crash.
        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedIndex == 0)
    }

    @Test func customEmojiStoreBacksUpCorruptDataInsteadOfSilentlyWiping() throws {
        // Regression: a corrupt JSON payload used to be silently replaced with [].
        // Now the corrupt blob is preserved under a backup key so the user can recover it.
        let defaults = UserDefaults(suiteName: "emoji-picker-tests-\(UUID().uuidString)")!
        let corruptPayload = Data("not valid json".utf8)
        defaults.set(corruptPayload, forKey: "customEmojis")

        let store = CustomEmojiStore(
            bundledEmojis: sampleEmojis,
            userDefaults: defaults,
            storageKey: "customEmojis"
        )

        #expect(store.customEmojis.isEmpty)
        let backup = defaults.data(forKey: "customEmojis.corruptBackup")
        #expect(backup == corruptPayload)
    }

    @Test func customEmojiStoreInvalidatesAllEmojisCacheOnMutation() throws {
        // Regression / cache-correctness: allEmojis and customPasteTexts are cached;
        // mutating the store must invalidate the cache so new entries appear.
        let defaults = UserDefaults(suiteName: "emoji-picker-tests-\(UUID().uuidString)")!
        let store = CustomEmojiStore(
            bundledEmojis: sampleEmojis,
            userDefaults: defaults,
            storageKey: "customEmojis"
        )

        let initialCount = store.allEmojis.count
        try store.add(name: "boom", pasteText: ":boom:")
        #expect(store.allEmojis.count == initialCount + 1)
        #expect(store.customPasteTexts.contains(":boom:"))
    }

    @Test func emojiUsageTrackerCachesAndPersistsUsage() {
        // Regression: EmojiUsageTracker used to deserialize the whole dict on every call.
        // Now it caches in memory; verify correctness is preserved across calls and persisted.
        let tracker = EmojiUsageTracker.shared
        tracker.clearUsageData()

        tracker.incrementUsage(for: "🔥")
        tracker.incrementUsage(for: "🔥")
        tracker.incrementUsage(for: "😀")

        // Multiple reads return consistent values (cache is not stale).
        #expect(tracker.getUsageCount(for: "🔥") == 2)
        #expect(tracker.getUsageCount(for: "🔥") == 2)
        #expect(tracker.getUsageCount(for: "😀") == 1)

        let mostUsed = tracker.getMostUsedEmojis(limit: 2)
        #expect(mostUsed.first?.emoji == "🔥")
        #expect(mostUsed.first?.count == 2)

        tracker.clearUsageData()
    }

    @Test func loadEmojisReturnsEmptyArrayWhenResourceIsMissing() {
        // Regression: loadEmojis used to fatalError on a missing bundle resource.
        // Now it logs and returns an empty array so the app still launches.
        let emojis = loadEmojis(from: "definitely-not-a-bundled-resource")
        #expect(emojis.isEmpty)
    }
}
