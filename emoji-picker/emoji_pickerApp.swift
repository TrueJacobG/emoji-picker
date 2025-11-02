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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusItem?.button else {
            print("Failed to create status bar button")
            return
        }
        
        button.title = "⭐️"
        button.action = #selector(togglePopover)
        button.target = self
        
        print("Status item created successfully")
        
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        checkAccessibilityPermissions()
        
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
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        
        print("✅ Keyboard monitoring setup complete")
        print("📝 Listening for: § key (keyCode 10)")
    }
    
    func handleKeyEvent(_ event: NSEvent) {
        // § key == 10
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
