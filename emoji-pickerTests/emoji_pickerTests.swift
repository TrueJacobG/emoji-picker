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
            emojis: sampleEmojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
        )

        let results = service.results(for: "smile", limit: 10)

        #expect(results.map(\.emoji.emoji) == ["😀", "🙂"])
    }

    @Test func usageCountBreaksTiesWithinTheSameRank() {
        let service = EmojiSearchService(
            emojis: sampleEmojis,
            usageCountProvider: { emoji in
                emoji == "🙂" ? 8 : 1
            },
            mostUsedProvider: { _ in [] }
        )

        let results = service.results(for: "smi", limit: 10)

        #expect(results.map(\.emoji.emoji) == ["🙂", "😀"])
    }

    @Test func emptySearchUsesMostUsedThenCuratedDefaults() {
        let service = EmojiSearchService(
            emojis: sampleEmojis,
            usageCountProvider: { emoji in
                emoji == "🔥" ? 5 : 0
            },
            mostUsedProvider: { _ in [("🔥", 5)] }
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
            emojis: duplicatedEmojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
        )

        let results = service.results(for: "face", limit: 10)

        #expect(results.contains(where: { $0.emoji.emoji == "😀" }))
    }

    @Test @MainActor func pickerViewModelResetsSelectionWhenSearchChanges() {
        let service = EmojiSearchService(
            emojis: sampleEmojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
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
            emojis: sampleEmojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
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
            emojis: sampleEmojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
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
            emojis: sampleEmojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
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
            emojis: sampleEmojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
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
            emojis: emojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
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
            emojis: emojis,
            usageCountProvider: { _ in 0 },
            mostUsedProvider: { _ in [] }
        )

        let results = service.results(for: "match", limit: 3)

        #expect(results.count == 3)
    }
}
