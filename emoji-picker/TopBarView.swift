import SwiftUI

struct TopBarView: View {
    @State private var hasAccessibility = AXIsProcessTrusted()
    
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
}
