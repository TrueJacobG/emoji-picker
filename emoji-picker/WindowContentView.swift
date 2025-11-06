import SwiftUI
import CoreGraphics

struct WindowContentView: View {
    
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
    }
    
    private func copyFirstEmoji() {
        guard let firstEmoji = filteredEmojis.first else {
            return
        }
        
        copyToClipboard(firstEmoji.emoji)
        
        searchText = ""
        
        NSApplication.shared.hide(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            paste()
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
        // Simulates a "Cmd + V" keystroke
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Keycode for "v" is 9
        let keyV = CGKeyCode(9)
        
        // Press Command + V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        keyDown?.flags = .maskCommand // Add Command flag
        
        // Release Command + V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        keyUp?.flags = .maskCommand // Add Command flag
        
        // Post the events
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

struct EmojiListView_Previews: PreviewProvider {
    static var previews: some View {
        WindowContentView()
    }
}
