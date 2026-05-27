import Foundation

struct CustomEmoji: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var pasteText: String

    init(id: UUID = UUID(), name: String, pasteText: String) {
        self.id = id
        self.name = name
        self.pasteText = pasteText
    }
}
