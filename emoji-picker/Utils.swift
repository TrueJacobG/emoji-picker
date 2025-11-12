import SwiftUI

func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    
    // track emoji usage
    EmojiUsageTracker.shared.incrementUsage(for: text)
}
