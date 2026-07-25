import SwiftUI

struct EmojiPickerView: View {
    @ObservedObject var viewModel: EmojiPickerViewModel
    @ObservedObject var customEmojiStore: CustomEmojiStore

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider()

            if viewModel.results.isEmpty {
                ContentUnavailableView(
                    "No matching emoji",
                    systemImage: "magnifyingglass",
                    description: Text("Try a shorter or broader search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                                EmojiResultRowView(
                                    result: result,
                                    isSelected: viewModel.selectedIndex == index,
                                    displayLetter: customEmojiStore.displayLetter(for: result.emoji.emoji),
                                    action: {
                                        viewModel.insert(result)
                                    }
                                )
                                .id(result.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: viewModel.selectedResult?.id) { _, selectedID in
                        guard let selectedID else {
                            return
                        }

                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(selectedID, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: AppConstants.defaultPickerWidth, height: AppConstants.defaultPickerHeight)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            focusSearchField()
        }
        .onChange(of: viewModel.presentationID) { _, _ in
            focusSearchField()
        }
    }

    private var searchBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search emoji by name", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 19, weight: .medium))
                    .focused($isSearchFocused)
                    .onSubmit {
                        viewModel.insertSelected()
                    }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Enter inserts the highlighted emoji")
                Spacer()
                Text("↑ ↓ moves selection")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }
}
