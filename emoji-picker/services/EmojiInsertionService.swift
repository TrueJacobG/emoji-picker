import AppKit
import ApplicationServices
import CoreGraphics

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
        guard let focusedElement = AXHelpers.getFocusedElement(from: systemWideElement) else {
            return false
        }

        if replaceSelectedText(in: focusedElement, with: emoji) {
            return true
        }

        if setFocusedElementValue(in: focusedElement, to: emoji) {
            return true
        }

        return false
    }

    private func replaceSelectedText(in element: AXUIElement, with replacement: String) -> Bool {
        guard let valueRef = AXHelpers.getValue(from: element),
              let currentText = textValue(from: valueRef) else {
            return false
        }

        guard let rangeValue = AXHelpers.getSelectedTextRange(from: element) else {
            return false
        }

        guard AXHelpers.getValueType(rangeValue) == .cfRange else {
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

        return apply(result, to: element)
    }

    private func setFocusedElementValue(in element: AXUIElement, to emoji: String) -> Bool {
        guard let valueRef = AXHelpers.getValue(from: element),
              let currentText = textValue(from: valueRef) else {
            return false
        }

        let result = appendText(currentText: currentText, text: emoji)

        return apply(result, to: element)
    }

    private func textValue(from valueRef: CFTypeRef) -> String? {
        if let str = valueRef as? String {
            return str
        }

        if let attrStr = valueRef as? NSAttributedString {
            return attrStr.string
        }

        return nil
    }

    private func apply(_ result: TextReplacementResult, to element: AXUIElement) -> Bool {
        if !AXHelpers.setValue(result.updatedText as CFTypeRef, for: element) {
            return false
        }

        // Verify the value was actually set (critical for Chromium contenteditables)
        if !AXHelpers.verifyValueWasSet(result.updatedText, for: element) {
            return false
        }

        var newSelection = CFRange(location: result.newCursorLocation, length: 0)
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
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: AppConstants.pasteVirtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: AppConstants.pasteVirtualKey, keyDown: false) else {
            snapshot.restore()
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Restore clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.clipboardRestoreDelay) {
            snapshot.restore()
        }

        return true
    }
}
