import SwiftUI
import CoreGraphics

struct WindowContentView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    enum Field: Hashable {
        case search
    }
    
    @FocusState private var focusedField: Field?
    
    private let allEmojis: [Emoji] = EmojiProvider.loadEmojis(from: "emoji2")
    
    var filteredEmojis: [Emoji] {
        if searchText.isEmpty {
            return allEmojis
        } else {
            return allEmojis.filter { emoji in
                emoji.name.contains { nameString in
                    nameString.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                TextField("Search emoji by name", text: $searchText, onCommit: {
                    copyFirstEmoji()
                })
                .focused($focusedField, equals: .search)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.title3)
                .padding(.vertical, 8)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                }
            }
            .background(.ultraThickMaterial)
            
            Divider()
            
            // emojis
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredEmojis, id: \.self) { emoji in
                        EmojiCell(emoji: emoji)
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 400)
        .onAppear {
            searchText = ""
            
            DispatchQueue.main.async {
                self.focusedField = .search
            }
        }
        
        Button("") {
            dismiss()
        }
        .keyboardShortcut(.cancelAction)
        .hidden()
    }
    
    private func copyFirstEmoji() {
        var emojiToPaste: String?
        
        if let firstEmoji = filteredEmojis.first {
            emojiToPaste = firstEmoji.emoji
            copyToClipboard(firstEmoji.emoji)
        }
        
        searchText = ""
        
        NSApplication.shared.hide(nil)
        
        if emojiToPaste != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                paste()
            }
        }
    }
    
    // TODO
    // code duplication
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func paste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let deleteKey = 51
        let keyDelete = CGKeyCode(deleteKey)
        
        let deleteDown = CGEvent(keyboardEventSource: source, virtualKey: keyDelete, keyDown: true)
        let deleteUp = CGEvent(keyboardEventSource: source, virtualKey: keyDelete, keyDown: false)
        
        let cmdPlusV = 9
        let keyV = CGKeyCode(cmdPlusV)
        
        let pasteDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        pasteDown?.flags = .maskCommand
        
        let pasteUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        pasteUp?.flags = .maskCommand
        
        deleteDown?.post(tap: .cghidEventTap)
        deleteUp?.post(tap: .cghidEventTap)
        
        pasteDown?.post(tap: .cghidEventTap)
        pasteUp?.post(tap: .cghidEventTap)
    }
}

struct EmojiListView_Previews: PreviewProvider {
    static var previews: some View {
        WindowContentView()
    }
}
