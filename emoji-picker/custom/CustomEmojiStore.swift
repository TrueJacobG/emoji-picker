import Combine
import Foundation

enum CustomEmojiStoreError: LocalizedError {
    case emptyName
    case emptyPasteText
    case duplicatePasteText

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Name cannot be empty."
        case .emptyPasteText:
            return "Paste text cannot be empty."
        case .duplicatePasteText:
            return "An emoji with this paste text already exists."
        }
    }
}

@MainActor
final class CustomEmojiStore: ObservableObject {
    static let shared = CustomEmojiStore()

    @Published private(set) var customEmojis: [CustomEmoji] = []

    private let userDefaults: UserDefaults
    private let storageKey: String
    let bundledEmojis: [Emoji]

    var customPasteTexts: Set<String> {
        Set(customEmojis.map(\.pasteText))
    }

    var allEmojis: [Emoji] {
        bundledEmojis + customEmojis.map { custom in
            Emoji(emoji: custom.pasteText, name: [custom.name, custom.pasteText])
        }
    }

    init(
        bundledEmojis: [Emoji] = EmojiProvider.loadEmojis(from: "emoji2"),
        userDefaults: UserDefaults = .standard,
        storageKey: String = "customEmojis"
    ) {
        self.bundledEmojis = bundledEmojis
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        load()
    }

    func isCustom(_ pasteText: String) -> Bool {
        customPasteTexts.contains(pasteText)
    }

    func displayLetter(for pasteText: String) -> String {
        let stripped = pasteText.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        let source = stripped.isEmpty ? pasteText : stripped
        guard let first = source.first else {
            return "?"
        }
        return String(first).uppercased()
    }

    @discardableResult
    func add(name: String, pasteText: String) throws -> CustomEmoji {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPasteText = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)

        try validate(name: trimmedName, pasteText: trimmedPasteText, excludingID: nil)

        let customEmoji = CustomEmoji(name: trimmedName, pasteText: trimmedPasteText)
        customEmojis.append(customEmoji)
        save()
        return customEmoji
    }

    @discardableResult
    func update(_ customEmoji: CustomEmoji, name: String, pasteText: String) throws -> CustomEmoji {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPasteText = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)

        try validate(name: trimmedName, pasteText: trimmedPasteText, excludingID: customEmoji.id)

        guard let index = customEmojis.firstIndex(where: { $0.id == customEmoji.id }) else {
            return customEmoji
        }

        let updated = CustomEmoji(id: customEmoji.id, name: trimmedName, pasteText: trimmedPasteText)
        customEmojis[index] = updated
        save()
        return updated
    }

    func delete(_ customEmoji: CustomEmoji) {
        customEmojis.removeAll { $0.id == customEmoji.id }
        save()
    }

    private func validate(name: String, pasteText: String, excludingID: UUID?) throws {
        guard !name.isEmpty else {
            throw CustomEmojiStoreError.emptyName
        }

        guard !pasteText.isEmpty else {
            throw CustomEmojiStoreError.emptyPasteText
        }

        let isDuplicate = customEmojis.contains { existing in
            existing.pasteText == pasteText && existing.id != excludingID
        }

        if isDuplicate {
            throw CustomEmojiStoreError.duplicatePasteText
        }
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            customEmojis = []
            return
        }

        do {
            customEmojis = try JSONDecoder().decode([CustomEmoji].self, from: data)
        } catch {
            customEmojis = []
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(customEmojis) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
