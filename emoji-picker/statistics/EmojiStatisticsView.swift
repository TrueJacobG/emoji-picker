import SwiftUI

struct EmojiStatisticsView: View {
    @ObservedObject var customEmojiStore: CustomEmojiStore

    @State private var searchText = ""
    @State private var sortMode: StatisticsSortMode = .default

    enum Field: Hashable {
        case search
    }

    @FocusState private var focusedField: Field?

    private var displayedEmojis: [Emoji] {
        let filtered: [Emoji]
        if searchText.isEmpty {
            filtered = customEmojiStore.allEmojis
        } else {
            filtered = customEmojiStore.allEmojis.filter { emoji in
                emoji.name.contains { nameString in
                    nameString.localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        return EmojiStatisticsSorter.sorted(
            filtered,
            mode: sortMode,
            bundledEmojis: customEmojiStore.bundledEmojis,
            usageCount: { EmojiUsageTracker.shared.getUsageCount(for: $0) }
        )
    }

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 60))
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                sortButton(mode: .mostUsed, icon: "arrow.down.circle", label: "Sort by most usage")
                sortButton(mode: .leastUsed, icon: "arrow.up.circle", label: "Sort by least usage")
                sortButton(mode: .default, icon: "list.bullet", label: "Default order")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThickMaterial)

            Divider()

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

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(displayedEmojis, id: \.self) { emoji in
                        EmojiCellWithStats(
                            emoji: emoji,
                            isCustom: customEmojiStore.isCustom(emoji.emoji),
                            displayLetter: customEmojiStore.displayLetter(for: emoji.emoji)
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            searchText = ""

            DispatchQueue.main.async {
                self.focusedField = .search
            }
        }
    }

    @ViewBuilder
    private func sortButton(mode: StatisticsSortMode, icon: String, label: String) -> some View {
        let button = Button {
            sortMode = mode
        } label: {
            Label(label, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.small)
        .help(label)

        if sortMode == mode {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
