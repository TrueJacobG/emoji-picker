import Combine
import Foundation
import OSLog

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

    private static let logger = Logger(subsystem: "com.github.truejacobg.emoji-picker", category: "customEmojiStore")

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let backupKey: String
    let bundledEmojis: [Emoji]

    private var cachedAllEmojis: [Emoji]?
    private var cachedCustomPasteTexts: Set<String>?

    var customPasteTexts: Set<String> {
        if let cached = cachedCustomPasteTexts {
            return cached
        }
        let value = Set(customEmojis.map(\.pasteText))
        cachedCustomPasteTexts = value
        return value
    }

    var allEmojis: [Emoji] {
        if let cached = cachedAllEmojis {
            return cached
        }
        let value = bundledEmojis + customEmojis.map { custom in
            Emoji(emoji: custom.pasteText, name: [custom.name, custom.pasteText])
        }
        cachedAllEmojis = value
        return value
    }

    init(
        bundledEmojis: [Emoji]? = nil,
        userDefaults: UserDefaults = .standard,
        storageKey: String = "customEmojis"
    ) {
        self.bundledEmojis = bundledEmojis ?? loadEmojis(from: "emoji2")
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.backupKey = "\(storageKey).corruptBackup"
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

    private func invalidateCaches() {
        cachedAllEmojis = nil
        cachedCustomPasteTexts = nil
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            customEmojis = []
            return
        }

        do {
            customEmojis = try JSONDecoder().decode([CustomEmoji].self, from: data)
        } catch {
            // Preserve the corrupt blob so the user can recover it, then start clean.
            Self.logger.error("Failed to decode custom emojis, backing up corrupt data: \(error.localizedDescription, privacy: .public)")
            userDefaults.set(data, forKey: backupKey)
            customEmojis = []
        }
    }

    private func save() {
        invalidateCaches()

        do {
            let data = try JSONEncoder().encode(customEmojis)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            Self.logger.error("Failed to encode custom emojis: \(error.localizedDescription, privacy: .public)")
        }
    }
}
