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
    private let customEmojiStore = CustomEmojiStore.shared
    private let popover = NSPopover()
    private lazy var statisticsController = HostingWindowController(
        rootView: EmojiStatisticsView(customEmojiStore: customEmojiStore),
        title: "Emoji Statistics",
        size: NSSize(width: 600, height: 500)
    )
    private lazy var customEmojiController = HostingWindowController(
        rootView: CustomEmojiView(store: customEmojiStore),
        title: "Custom Emoji",
        size: NSSize(width: 500, height: 450)
    )

    private lazy var pickerCoordinator: PickerCoordinator = PickerCoordinator(
        searchService: EmojiSearchService(
            emojiProvider: { [customEmojiStore] in customEmojiStore.allEmojis },
            isCustomProvider: { [customEmojiStore] in customEmojiStore.isCustom($0) }
        ),
        insertionService: EmojiInsertionService(),
        customEmojiStore: customEmojiStore
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

        let isTestMode = ProcessInfo.processInfo.environment["EMOJI_PICKER_TEST_MODE"] == "1"

        if !isTestMode {
            appState.attach(hotkeyService: hotkeyService)
            appState.requestInitialPermissions()
        }

        appState.applyLaunchAtLoginPreference()
        appState.refreshAll()

        if !isTestMode {
            hotkeyService.start()
            appState.refreshAll()
        }
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
        popover.contentSize = NSSize(width: AppConstants.popoverWidth, height: AppConstants.popoverHeight)
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
                },
                showCustomEmoji: { [weak self] in
                    self?.customEmojiController.showWindow()
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
