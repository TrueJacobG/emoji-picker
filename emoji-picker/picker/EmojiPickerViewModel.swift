import AppKit
import Combine
import Foundation

@MainActor
final class EmojiPickerViewModel: ObservableObject {
    @Published var searchText = "" {
        didSet {
            refreshResults(resetSelection: true)
        }
    }

    @Published private(set) var results: [EmojiSearchResult] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var presentationID = UUID()

    let searchService: EmojiSearchService
    var onInsert: ((EmojiSearchResult) -> Void)?

    init(searchService: EmojiSearchService) {
        self.searchService = searchService
        refreshResults(resetSelection: true)
    }

    var selectedResult: EmojiSearchResult? {
        guard results.indices.contains(selectedIndex) else {
            return nil
        }

        return results[selectedIndex]
    }

    func prepareForPresentation() {
        searchText = ""
        refreshResults(resetSelection: true)
        presentationID = UUID()
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else {
            NSSound.beep()
            return
        }

        selectedIndex = max(0, min(selectedIndex + delta, results.count - 1))
    }

    func insertSelected() {
        guard let selectedResult else {
            NSSound.beep()
            return
        }

        onInsert?(selectedResult)
    }

    func insert(_ result: EmojiSearchResult) {
        onInsert?(result)
    }

    private func refreshResults(resetSelection: Bool) {
        results = searchService.results(for: searchText)

        if resetSelection {
            selectedIndex = 0
        } else if selectedIndex >= results.count {
            selectedIndex = max(0, results.count - 1)
        }
    }
}
