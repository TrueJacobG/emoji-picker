import SwiftUI

struct WindowContentView: View {
    
    // 1. State variable to hold the user's search query
    @State private var searchText = ""
    
    // 2. Load the emoji data using the EmojiProvider
    // This is done once when the view is initialized.
    private let allEmojis: [Emoji] = EmojiProvider.loadEmojis(from: "emoji")

    // 3. A computed property to filter the emojis based on the search text
    var filteredEmojis: [Emoji] {
        if searchText.isEmpty {
            // If search is empty, return all emojis
            return allEmojis
        } else {
            // Otherwise, filter the list based on the emoji's name
            return allEmojis.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 4. Define the grid layout
    // This creates an adaptive grid where each item has a
    // minimum width of 60 points, so SwiftUI will fit
    // as many columns as possible.
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 60))
    ]

    var body: some View {
        VStack(spacing: 0) {
            
            // --- SEARCH BAR ---
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                TextField("Search emoji by name", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.title3)
                    .padding(.vertical, 8)
                
                // Add a clear button that appears when text is present
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
            // Use a system material background for the search bar
            .background(.ultraThickMaterial)
            
            Divider()

            // --- EMOJI GRID ---
            ScrollView {
                // LazyVGrid is efficient as it only loads items as they appear
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredEmojis, id: \.self) { emoji in
                        VStack {
                            Text(emoji.emoji)
                                .font(.system(size: 36)) // Large emoji
                            
                            Text(emoji.name)
                                .font(.caption2) // Small name
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(height: 28) // Fixed height for name
                        }
                        .frame(width: 70, height: 70) // Fixed size for the whole item
                        .padding(4)
                        .background(
                            // Use system background color for hover effect
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .onTapGesture {
                            // Action: Copy emoji to clipboard
                            print("Copied: \(emoji.emoji)")
                            copyToClipboard(emoji.emoji)
                        }
                    }
                }
                .padding()
            }
        }
        // Set a good default size for the window
        .frame(width: 480, height: 400)
    }
    
    /**
     Helper function to copy the selected emoji string to the system pasteboard.
     */
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// --- PREVIEW ---
struct EmojiListView_Previews: PreviewProvider {
    static var previews: some View {
        WindowContentView()
    }
}
