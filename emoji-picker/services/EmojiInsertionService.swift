import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class EmojiInsertionService {
    func insert(_ emoji: String, into previousApp: NSRunningApplication?, completion: @escaping (Bool) -> Void) {
        restore(previousApp: previousApp)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let insertedDirectly = self.insertDirectlyIntoFocusedElement(emoji)
            let didInsert = insertedDirectly || self.pasteUsingClipboard(emoji)
            completion(didInsert)
        }
    }

    private func restore(previousApp: NSRunningApplication?) {
        guard let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        previousApp.activate(options: [.activateAllWindows])
    }

    private func insertDirectlyIntoFocusedElement(_ emoji: String) -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        ) == .success,
        let focusedElementRef else {
            return false
        }

        let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)
        return replaceSelectedText(in: focusedElement, with: emoji)
    }

    private func replaceSelectedText(in element: AXUIElement, with replacement: String) -> Bool {
        var currentValueRef: CFTypeRef?
        var selectedRangeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &currentValueRef
        ) == .success,
        let currentValue = currentValueRef as? String,
        AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        ) == .success,
        let selectedRangeRef else {
            return false
        }

        let rangeValue = unsafeBitCast(selectedRangeRef, to: AXValue.self)
        guard AXValueGetType(rangeValue) == .cfRange else {
            return false
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &selectedRange) else {
            return false
        }

        let nsCurrentValue = currentValue as NSString
        let selectedNSRange = NSRange(location: selectedRange.location, length: selectedRange.length)
        guard selectedNSRange.location != NSNotFound,
              selectedNSRange.location + selectedNSRange.length <= nsCurrentValue.length else {
            return false
        }

        let updatedValue = nsCurrentValue.replacingCharacters(in: selectedNSRange, with: replacement)

        guard AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        ) == .success else {
            return false
        }

        var newSelection = CFRange(location: selectedRange.location + (replacement as NSString).length, length: 0)
        guard let newSelectionValue = AXValueCreate(.cfRange, &newSelection) else {
            return true
        }

        _ = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            newSelectionValue
        )

        return true
    }

    private func pasteUsingClipboard(_ emoji: String) -> Bool {
        let snapshot = PasteboardSnapshot.capture()
        writeStringToPasteboard(emoji)

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            snapshot.restore()
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            snapshot.restore()
        }

        return true
    }
}
