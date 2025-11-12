import SwiftUI

struct TopBarView: View {
    @State private var hasAccessibility = AXIsProcessTrusted()
    
    static var statisticsWindow: NSWindow?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Menu Bar App")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text("Press this key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ActivationKeyIcon(text: "§")
            }
            
            HStack(spacing: 6) {
                Circle()
                    .fill(hasAccessibility ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(hasAccessibility ? "Accessibility: Enabled" : "Accessibility: Disabled")
                    .font(.caption)
                    .foregroundColor(hasAccessibility ? .green : .red)
            }
            
            if !hasAccessibility {
                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // statistics
            Button("View Statistics") {
                openStatisticsWindow()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // quit
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(30)
        .frame(width: 300, height: 240)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                hasAccessibility = AXIsProcessTrusted()
            }
        }
    }
    
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func openStatisticsWindow() {
        if let existingWindow = TopBarView.statisticsWindow {
            existingWindow.close()
            TopBarView.statisticsWindow = nil
        }
        
        let statisticsView = EmojiStatisticsView()
        let hostingController = NSHostingController(rootView: statisticsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Emoji Statistics"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        TopBarView.statisticsWindow = window
        window.delegate = WindowCleanupDelegate.shared
    }
}

class WindowCleanupDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowCleanupDelegate()
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow,
           window.title == "Emoji Statistics" {
            TopBarView.statisticsWindow = nil
        }
    }
}

struct ActivationKeyIcon: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}
