import SwiftUI
import Carbon

@main
struct emoji_pickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var window: NSWindow?
    var eventMonitor: Any?
    var localEventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusItem?.button else {
            print("Failed to create status bar button")
            return
        }
        
        button.title = "⭐️"
        button.action = #selector(togglePopover)
        button.target = self
        
        print("Status item created successfully")
        
        // Configure the popover
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        // Check for accessibility permissions
        checkAccessibilityPermissions()
        
        // Setup keyboard monitoring with both global and local monitors
        setupKeyboardMonitoring()
    }
    
    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("⚠️ Accessibility permissions not granted. Please grant permissions in System Settings > Privacy & Security > Accessibility")
        } else {
            print("✅ Accessibility permissions granted!")
        }
    }
    
    func setupKeyboardMonitoring() {
        // Global monitor - works when other apps are active
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor - works when our app is active
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        
        print("✅ Keyboard monitoring setup complete")
        print("📝 Listening for: § key (keyCode 10)")
    }
    
    func handleKeyEvent(_ event: NSEvent) {
        // Check for § key (keyCode 10)
        // Can use with or without modifiers
        if event.keyCode == 10 {
            print("🎉 § key detected!")
            showWindow()
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    func showWindow() {
        DispatchQueue.main.async {
            if self.window == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                window.center()
                window.title = "Hotkey Triggered!"
                window.contentView = NSHostingView(rootView: WindowContentView())
                window.isReleasedWhenClosed = false
                window.level = .floating
                self.window = window
            }
            
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ Window shown!")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct ContentView: View {
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
                
                KeyCapView(text: "§")
            }
            
            // Accessibility status
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
            // Check every 2 seconds if permissions changed
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

struct KeyCapView: View {
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

struct WindowContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Hotkey Detected!")
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                Text("You pressed")
                KeyCapView(text: "§")
            }
            
            Divider()
                .padding(.vertical)
            
            Text("This window appeared from anywhere in macOS!\nTry it from Safari, Finder, or any other app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.callout)
        }
        .padding(40)
        .frame(width: 400, height: 300)
    }
}
