import AppKit
import ApplicationServices
import CoreGraphics
import OSLog

@MainActor
final class EmojiInsertionService {
    func insert(_ emoji: String, into previousApp: NSRunningApplication?, refocusElement: AXUIElement?, completion: @escaping (Bool) -> Void) {
        restore(previousApp: previousApp)

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.refocusDelay) {
            if let refocusElement {
                self.refocusElement(refocusElement)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.insertionDelay) {
                let insertedDirectly = self.insertDirectlyIntoFocusedElement(emoji)
                if insertedDirectly {
                    completion(true)
                    return
                }

                let pasted = self.pasteUsingClipboard(emoji)
                completion(pasted)
            }
        }
    }

    private func restore(previousApp: NSRunningApplication?) {
        guard let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        previousApp.activate(options: [.activateAllWindows])
    }

    private func refocusElement(_ element: AXUIElement) {
        guard let actionNames = AXHelpers.getActionNames(for: element) else {
            _ = AXHelpers.setFocused(element)
            return
        }
        
        if actionNames.contains("AXPress") {
            _ = AXHelpers.performAction("AXPress", on: element)
        } else {
            _ = AXHelpers.setFocused(element)
        }
    }

    private func insertDirectlyIntoFocusedElement(_ emoji: String) -> Bool {
        let systemWideElement = AXHelpers.createSystemWideElement()
        guard let focusedElementRef = AXHelpers.getFocusedElement(from: systemWideElement) else {
            return false
        }

        let focusedElement = AXHelpers.convertToAXUIElement(focusedElementRef)

        if replaceSelectedText(in: focusedElement, with: emoji) {
            return true
        }

        if setFocusedElementValue(in: focusedElement, to: emoji) {
            return true
        }
        
        return false
    }

    private func replaceSelectedText(in element: AXUIElement, with replacement: String) -> Bool {
        guard let valueRef = AXHelpers.getValue(from: element) else {
            return false
        }

        let currentText: String
        if let str = valueRef as? String {
            currentText = str
        } else if let attrStr = valueRef as? NSAttributedString {
            currentText = attrStr.string
        } else {
            return false
        }

        guard let selectedRangeRef = AXHelpers.getSelectedTextRange(from: element) else {
            return false
        }

        let rangeValue = AXHelpers.convertToAXValue(selectedRangeRef)
        let rangeType = AXHelpers.getValueType(rangeValue)
        guard rangeType == .cfRange else {
            return false
        }

        var selectedRange = CFRange()
        guard AXHelpers.getValue(rangeValue, type: .cfRange, outValue: &selectedRange) else {
            return false
        }

        let result = replaceTextAtSelection(
            currentText: currentText,
            selectionLocation: selectedRange.location,
            selectionLength: selectedRange.length,
            replacement: replacement
        )

        guard case .success(let updatedValue, let newCursorLocation) = result else {
            return false
        }

        if !AXHelpers.setValue(updatedValue as CFTypeRef, for: element) {
            return false
        }

        // Verify the value was actually set (critical for Chromium contenteditables)
        if !AXHelpers.verifyValueWasSet(updatedValue, for: element) {
            return false
        }

        var newSelection = CFRange(location: newCursorLocation, length: 0)
        if let newSelectionValue = AXValueCreate(.cfRange, &newSelection) {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                newSelectionValue
            )
        }

        return true
    }

    private func setFocusedElementValue(in element: AXUIElement, to emoji: String) -> Bool {
        guard let valueRef = AXHelpers.getValue(from: element) else {
            return false
        }

        let currentText: String
        if let str = valueRef as? String {
            currentText = str
        } else if let attrStr = valueRef as? NSAttributedString {
            currentText = attrStr.string
        } else {
            return false
        }

        let result = appendText(currentText: currentText, text: emoji)

        guard case .success(let updatedValue, let newCursorLocation) = result else {
            return false
        }

        if !AXHelpers.setValue(updatedValue as CFTypeRef, for: element) {
            return false
        }

        // Verify the value was actually set (critical for Chromium contenteditables)
        if !AXHelpers.verifyValueWasSet(updatedValue, for: element) {
            return false
        }

        var newSelection = CFRange(location: newCursorLocation, length: 0)
        if let newSelectionValue = AXValueCreate(.cfRange, &newSelection) {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                newSelectionValue
            )
        }

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

        // Restore clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            snapshot.restore()
        }

        return true
    }
}
