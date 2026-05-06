import SwiftUI

@main
struct emoji_pickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private let popover = NSPopover()
    private let statisticsController = StatisticsWindowController()

    private lazy var pickerCoordinator = PickerCoordinator(
        searchService: EmojiSearchService(),
        insertionService: EmojiInsertionService()
    )

    private lazy var hotkeyService = HotkeyService(
        onHotkey: { [weak self] in
            self?.requestPickerPresentation()
        },
        onAvailabilityChanged: { [weak self] isAvailable in
            self?.appState.setHotkeyCaptureAvailable(isAvailable)
        }
    )

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()

        appState.attach(hotkeyService: hotkeyService)
        appState.applyLaunchAtLoginPreference()
        appState.refreshAll()
        appState.requestInitialPermissions()

        hotkeyService.start()
        appState.refreshAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService.stop()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Emoji Picker")
        button.action = #selector(togglePopover)
        button.target = self

        self.statusItem = statusItem
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 340, height: 320)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: TopBarView(
                appState: appState,
                openPicker: { [weak self] in
                    self?.requestPickerPresentation()
                },
                showStatistics: { [weak self] in
                    self?.statisticsController.showWindow()
                }
            )
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            appState.refreshAll()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func requestPickerPresentation() {
        popover.performClose(nil)

        DispatchQueue.main.async { [weak self] in
            self?.pickerCoordinator.showPicker()
        }
    }
}

@MainActor
final class StatisticsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: EmojiStatisticsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Emoji Statistics"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
