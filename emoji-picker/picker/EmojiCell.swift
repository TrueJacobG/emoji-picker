import SwiftUI

struct EmojiCell: View {
    let emoji: Emoji
    
    @State private var isHovering = false
    
    @State private var showCopiedMessage = false
    
    var body: some View {
        ZStack {
            VStack {
                Text(emoji.emoji)
                    .font(.system(size: 36))
                
                Text(emoji.name[0])
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
                    .opacity(isHovering ? 1.0 : 0.0)
                    .animation(.default, value: isHovering)
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
            
            if showCopiedMessage {
                Text("Copied!")
                    .font(.caption)
                    .bold()
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(0.9)))
                    .zIndex(1)
            }
        }.onTapGesture {
            copyToClipboard(emoji.emoji)
            
            withAnimation {
                showCopiedMessage = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showCopiedMessage = false
                }
            }
        }
        
    }
}
