import AppKit
import SwiftUI
import ApplicationServices

@MainActor
final class PickerCoordinator: NSObject, NSWindowDelegate {
    private let searchService: EmojiSearchService
    private let insertionService: EmojiInsertionService
    private let customEmojiStore: CustomEmojiStore
    private let viewModel: EmojiPickerViewModel

    private var panel: PickerPanel?
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var focusedElementBeforePicker: AXUIElement?
    private var isClosing = false
    private var isInserting = false

    init(searchService: EmojiSearchService, insertionService: EmojiInsertionService, customEmojiStore: CustomEmojiStore) {
        self.searchService = searchService
        self.insertionService = insertionService
        self.customEmojiStore = customEmojiStore
        self.viewModel = EmojiPickerViewModel(searchService: searchService)
        super.init()

        viewModel.onInsert = { [weak self] result in
            self?.insert(result)
        }
    }

    func showPicker() {
        DispatchQueue.main.async { [weak self] in
            self?.presentPicker()
        }
    }

    private func presentPicker() {
        guard !isInserting else {
            return
        }

        let panel = makePanelIfNeeded()

        if panel.isVisible {
            activatePickerApp()
            panel.orderFrontRegardless()
            panel.makeKey()
            return
        }

        previousApp = currentExternalFrontmostApplication()
        focusedElementBeforePicker = captureFocusedElement()
        
        // Log picker open details
        InsertionLogger.log("PICKER-OPEN", "Picker opened. previousApp=\(previousApp?.bundleIdentifier ?? "nil"), focusedElement=\(describeAXElement(focusedElementBeforePicker))")

        isClosing = false
        viewModel.prepareForPresentation()

        position(panel)
        installKeyMonitorIfNeeded()
        activatePickerApp()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanelIfNeeded() -> PickerPanel {
        if let panel {
            return panel
        }

        let panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.isExcludedFromWindowsMenu = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: EmojiPickerView(
                viewModel: viewModel,
                customEmojiStore: customEmojiStore
            )
        )

        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main

        guard let targetScreen else {
            panel.center()
            return
        }

        let frame = panel.frame
        let origin = NSPoint(
            x: targetScreen.visibleFrame.midX - (frame.width / 2),
            y: targetScreen.visibleFrame.midY - (frame.height / 2)
        )

        panel.setFrameOrigin(origin)
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event) ?? event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard panel?.isVisible == true else {
            return event
        }

        if event.modifierFlags.intersection([.command, .control, .option]).isEmpty == false {
            return event
        }

        switch event.keyCode {
        case 53:
            closePicker(restorePreviousApp: true)
            return nil
        case 36, 76:
            viewModel.insertSelected()
            return nil
        case 125:
            viewModel.moveSelection(by: 1)
            return nil
        case 126:
            viewModel.moveSelection(by: -1)
            return nil
        default:
            return event
        }
    }

    private func insert(_ result: EmojiSearchResult) {
        guard !isInserting else {
            return
        }

        isInserting = true
        closePicker(restorePreviousApp: false)

        insertionService.insert(result.emoji.emoji, into: previousApp, refocusElement: focusedElementBeforePicker) { [weak self] success in
            guard let self else {
                return
            }

            // Log insertion result
            InsertionLogger.log("INSERT-COMPLETE", "Insertion completed. emoji=\(result.emoji.emoji), success=\(success), beep=\(!success)")
            
            if success {
                EmojiUsageTracker.shared.incrementUsage(for: result.emoji.emoji)
            } else {
                NSSound.beep()
            }

            self.isInserting = false
            self.previousApp = nil
            self.focusedElementBeforePicker = nil
        }
    }

    private func closePicker(restorePreviousApp: Bool) {
        guard let panel, panel.isVisible, !isClosing else {
            return
        }

        isClosing = true
        panel.orderOut(nil)
        removeKeyMonitor()

        if restorePreviousApp {
            guard let app = previousApp, app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return
            }

            app.activate(options: [.activateAllWindows])
            previousApp = nil
        }

        isClosing = false
    }

    private func captureFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &elementRef
        ) == .success, let elementRef else {
            return nil
        }
        return unsafeBitCast(elementRef, to: AXUIElement.self)
    }
    
    private func describeAXElement(_ element: AXUIElement?) -> String {
        guard let element = element else {
            return "nil"
        }
        
        var role: CFTypeRef?
        var subrole: CFTypeRef?
        var identifier: CFTypeRef?
        var title: CFTypeRef?
        
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        let roleStr = (role as? String) ?? "nil"
        let subroleStr = (subrole as? String) ?? "nil"
        let identifierStr = (identifier as? String) ?? "nil"
        let titleStr = (title as? String) ?? "nil"
        
        return "\(roleStr):\(subroleStr):\(identifierStr):\(titleStr)"
    }

    private func currentExternalFrontmostApplication() -> NSRunningApplication? {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let candidate = NSWorkspace.shared.frontmostApplication

        guard candidate?.bundleIdentifier != bundleIdentifier else {
            return previousApp
        }

        return candidate
    }

    private func activatePickerApp() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
