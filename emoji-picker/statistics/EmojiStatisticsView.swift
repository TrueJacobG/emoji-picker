import SwiftUI

struct EmojiStatisticsView: View {
    
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
                
                TextField("Search emoji by name", text: $searchText)
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
                        EmojiCellWithStats(emoji: emoji)
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
    }
}
