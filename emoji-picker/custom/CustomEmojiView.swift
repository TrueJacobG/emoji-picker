import SwiftUI

struct CustomEmojiView: View {
    @ObservedObject var store: CustomEmojiStore

    @State private var editorMode: EditorMode?
    @State private var pendingDelete: CustomEmoji?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Custom Emoji")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Add") {
                    editorMode = .add
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if store.customEmojis.isEmpty {
                ContentUnavailableView(
                    "No custom emoji yet",
                    systemImage: "face.smiling.inverse",
                    description: Text("Add Slack-style shortcuts like :super_smile: and paste them from the picker.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.customEmojis) { customEmoji in
                        HStack(spacing: 12) {
                            CustomEmojiBadge(letter: store.displayLetter(for: customEmoji.pasteText))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(customEmoji.name)
                                    .font(.headline)

                                Text(customEmoji.pasteText)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Edit") {
                                editorMode = .edit(customEmoji)
                            }
                            .buttonStyle(.bordered)

                            Button("Delete", role: .destructive) {
                                pendingDelete = customEmoji
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            CustomEmojiEditorSheet(store: store, mode: mode)
        }
        .alert(
            "Delete custom emoji?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { customEmoji in
            Button("Delete", role: .destructive) {
                store.delete(customEmoji)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { customEmoji in
            Text("Remove \(customEmoji.name) (\(customEmoji.pasteText))?")
        }
    }
}

private enum EditorMode: Identifiable {
    case add
    case edit(CustomEmoji)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let customEmoji):
            return customEmoji.id.uuidString
        }
    }
}

private struct CustomEmojiEditorSheet: View {
    @ObservedObject var store: CustomEmojiStore
    let mode: EditorMode

    @Environment(\.dismiss) private var dismiss

    @State private var pasteText = ""
    @State private var name = ""
    @State private var hasEditedName = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sheetTitle)
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste text")
                    .font(.headline)

                TextField("e.g. :super_smile:", text: $pasteText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: pasteText) { _, newValue in
                        if !hasEditedName || name.isEmpty {
                            name = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.headline)

                TextField("Display name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { _, _ in
                        hasEditedName = true
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            switch mode {
            case .add:
                pasteText = ""
                name = ""
                hasEditedName = false
            case .edit(let customEmoji):
                pasteText = customEmoji.pasteText
                name = customEmoji.name
                hasEditedName = true
            }
        }
    }

    private var sheetTitle: String {
        switch mode {
        case .add:
            return "Add Custom Emoji"
        case .edit:
            return "Edit Custom Emoji"
        }
    }

    private func save() {
        do {
            switch mode {
            case .add:
                _ = try store.add(name: name, pasteText: pasteText)
            case .edit(let customEmoji):
                _ = try store.update(customEmoji, name: name, pasteText: pasteText)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
