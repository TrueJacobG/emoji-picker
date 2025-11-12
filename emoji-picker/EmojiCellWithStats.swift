import SwiftUI

struct EmojiCellWithStats: View {
    let emoji: Emoji
    
    @State private var isHovering = false
    @State private var showCopiedMessage = false
    @State private var usageCount = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(emoji.emoji)
                    .font(.system(size: 36))
                
                Text(emoji.name[0])
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
                    .opacity(isHovering ? 1.0 : 0.0)
                    .animation(.default, value: isHovering)
                
                Text("\(usageCount) use\(usageCount == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .frame(width: 70, height: 70)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .onHover { hovering in
                self.isHovering = hovering
            }
        }
        .onAppear {
            usageCount = EmojiUsageTracker.shared.getUsageCount(for: emoji.emoji)
        }
    }
}
