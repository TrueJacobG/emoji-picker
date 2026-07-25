import AppKit
import SwiftUI

@MainActor
final class HostingWindowController<RootView: View>: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let rootView: RootView
    private let title: String
    private let size: NSSize

    init(rootView: RootView, title: String, size: NSSize) {
        self.rootView = rootView
        self.title = title
        self.size = size
        super.init()
    }

    func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            HostingWindowController.activate()
            return
        }

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(size)
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        self.window = window
        HostingWindowController.activate()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private static func activate() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
