import AppKit
import ApplicationServices
import CoreGraphics
import OSLog

@MainActor
final class EmojiInsertionService {
    func insert(_ emoji: String, into previousApp: NSRunningApplication?, refocusElement: AXUIElement?, completion: @escaping (Bool) -> Void) {
        InsertionLogger.log("INSERT", "Starting insertion. emoji=\(emoji), previousApp=\(previousApp?.bundleIdentifier ?? "nil"), hasRefocusElement=\(refocusElement != nil)")
        
        restore(previousApp: previousApp)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let refocusElement {
                self.refocusElement(refocusElement)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let insertedDirectly = self.insertDirectlyIntoFocusedElement(emoji)
                if insertedDirectly {
                    InsertionLogger.log("INSERT", "Direct AX insertion succeeded")
                    completion(true)
                    return
                }

                let pasted = self.pasteUsingClipboard(emoji)
                InsertionLogger.log("INSERT", "Clipboard paste fallback \(pasted ? "initiated" : "failed to initiate")")
                completion(pasted)
            }
        }
    }

    private func restore(previousApp: NSRunningApplication?) {
        guard let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            InsertionLogger.log("RESTORE", "Skipping restore - no previous app or it's our own app")
            return
        }

        InsertionLogger.log("RESTORE", "Activating previous app: \(previousApp.bundleIdentifier ?? "nil")")
        previousApp.activate(options: [.activateAllWindows])
    }

    private func refocusElement(_ element: AXUIElement) {
        InsertionLogger.log("AX-REFOCUS", "Attempting to refocus element: \(describeAXElement(element))")
        
        var actionNamesRef: CFArray?
        guard AXUIElementCopyActionNames(element, &actionNamesRef) == .success,
              let actionNames = actionNamesRef as? [String] else {
            InsertionLogger.log("AX-REFOCUS", "Failed to get action names, falling back to AXFocused")
            AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, true as CFTypeRef)
            return
        }
        
        InsertionLogger.log("AX-REFOCUS", "Available actions: \(actionNames)")
        
        if actionNames.contains("AXPress") {
            InsertionLogger.log("AX-REFOCUS", "Using AXPress action")
            AXUIElementPerformAction(element, "AXPress" as CFString)
        } else {
            InsertionLogger.log("AX-REFOCUS", "Using AXFocused fallback")
            AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, true as CFTypeRef)
        }
    }
    
    private func describeAXElement(_ element: AXUIElement) -> String {
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

    private func insertDirectlyIntoFocusedElement(_ emoji: String) -> Bool {
        InsertionLogger.log("AX-DIRECT", "Attempting direct AX insertion of \(emoji)")
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?

        let focusError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        
        guard focusError == .success, let focusedElementRef else {
            InsertionLogger.log("AX-DIRECT", "Failed to get focused element. AXError=\(focusError.rawValue), elementRef=\(focusedElementRef != nil)")
            return false
        }

        let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)
        InsertionLogger.log("AX-DIRECT", "Got focused element: \(describeAXElement(focusedElement))")

        if replaceSelectedText(in: focusedElement, with: emoji) {
            InsertionLogger.log("AX-DIRECT", "replaceSelectedText succeeded")
            return true
        }

        if setFocusedElementValue(in: focusedElement, to: emoji) {
            InsertionLogger.log("AX-DIRECT", "setFocusedElementValue succeeded")
            return true
        }
        
        InsertionLogger.log("AX-DIRECT", "Both AX methods failed, falling back to clipboard")
        return false
    }

    private func replaceSelectedText(in element: AXUIElement, with replacement: String) -> Bool {
        InsertionLogger.log("AX-REPLACE", "Starting replaceSelectedText with replacement=\(replacement)")
        
        var currentValueRef: CFTypeRef?
        var selectedRangeRef: CFTypeRef?

        let valueError = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &currentValueRef
        )
        
        guard valueError == .success else {
            InsertionLogger.log("AX-REPLACE", "Failed to get AXValue. AXError=\(valueError.rawValue)")
            return false
        }
        
        let typeID = CFGetTypeID(currentValueRef)
        let isString = typeID == CFStringGetTypeID()
        let isAttributedString = typeID == CFAttributedStringGetTypeID()
        InsertionLogger.log("AX-REPLACE", "AXValue CFTypeID=\(typeID), isString=\(isString), isAttributedString=\(isAttributedString)")
        
        let currentText: String
        if let str = currentValueRef as? String {
            currentText = str
        } else if let attrStr = currentValueRef as? NSAttributedString {
            currentText = attrStr.string
        } else {
            InsertionLogger.log("AX-REPLACE", "AXValue is neither String nor NSAttributedString, cannot process")
            return false
        }
        
        InsertionLogger.log("AX-REPLACE", "Current text (truncated): \(currentText.prefix(100)) (length=\(currentText.count))")

        let rangeError = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        )
        
        guard rangeError == .success, let selectedRangeRef else {
            InsertionLogger.log("AX-REPLACE", "Failed to get selected text range. AXError=\(rangeError.rawValue), rangeRef=\(selectedRangeRef != nil)")
            return false
        }

        let rangeValue = unsafeBitCast(selectedRangeRef, to: AXValue.self)
        let rangeType = AXValueGetType(rangeValue)
        guard rangeType == .cfRange else {
            InsertionLogger.log("AX-REPLACE", "Selected text range is not CFRange type: \(rangeType.rawValue)")
            return false
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &selectedRange) else {
            InsertionLogger.log("AX-REPLACE", "Failed to get CFRange value from AXValue")
            return false
        }
        
        InsertionLogger.log("AX-REPLACE", "Selected range: location=\(selectedRange.location), length=\(selectedRange.length)")

        let result = replaceTextAtSelection(
            currentText: currentText,
            selectionLocation: selectedRange.location,
            selectionLength: selectedRange.length,
            replacement: replacement
        )

        guard case .success(let updatedValue, let newCursorLocation) = result else {
            InsertionLogger.log("AX-REPLACE", "Failed to compute replacement text")
            return false
        }
        
        InsertionLogger.log("AX-REPLACE", "Computed updated value (truncated): \(updatedValue.prefix(100)) (length=\(updatedValue.count)), newCursorLocation=\(newCursorLocation)")

        let setError = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        )
        
        if setError != .success {
            InsertionLogger.log("AX-REPLACE", "Failed to set AXValue. AXError=\(setError.rawValue)")
            return false
        }
        
        // Verify the value was actually set (critical for Chromium contenteditables)
        var verifyValueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &verifyValueRef) == .success {
            let verifyText: String?
            if let str = verifyValueRef as? String {
                verifyText = str
            } else if let attrStr = verifyValueRef as? NSAttributedString {
                verifyText = attrStr.string
            } else {
                verifyText = nil
            }
            
            if let verifyText = verifyText {
                let matches = verifyText == updatedValue
                InsertionLogger.log("AX-REPLACE", "Verified AXValue was set. Matches expected=\(matches), actual (truncated): \(verifyText.prefix(100))")
                
                // Critical fix: if the value didn't actually change, treat as failure
                if !matches {
                    InsertionLogger.log("AX-REPLACE", "AX write returned success but value did not change - treating as failure")
                    return false
                }
            } else {
                InsertionLogger.log("AX-REPLACE", "Could not verify AXValue - verification value type unknown")
                return false
            }
        } else {
            InsertionLogger.log("AX-REPLACE", "Could not verify AXValue - failed to read back")
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
        InsertionLogger.log("AX-APPEND", "Starting setFocusedElementValue with emoji=\(emoji)")
        
        var currentValueRef: CFTypeRef?

        let valueError = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &currentValueRef
        )
        
        guard valueError == .success else {
            InsertionLogger.log("AX-APPEND", "Failed to get AXValue. AXError=\(valueError.rawValue)")
            return false
        }
        
        let typeID = CFGetTypeID(currentValueRef)
        let isString = typeID == CFStringGetTypeID()
        let isAttributedString = typeID == CFAttributedStringGetTypeID()
        InsertionLogger.log("AX-APPEND", "AXValue CFTypeID=\(typeID), isString=\(isString), isAttributedString=\(isAttributedString)")
        
        let currentText: String
        if let str = currentValueRef as? String {
            currentText = str
        } else if let attrStr = currentValueRef as? NSAttributedString {
            currentText = attrStr.string
        } else {
            InsertionLogger.log("AX-APPEND", "AXValue is neither String nor NSAttributedString, cannot process")
            return false
        }
        
        InsertionLogger.log("AX-APPEND", "Current text (truncated): \(currentText.prefix(100)) (length=\(currentText.count))")

        let result = appendText(currentText: currentText, text: emoji)

        guard case .success(let updatedValue, let newCursorLocation) = result else {
            InsertionLogger.log("AX-APPEND", "Failed to compute appended text")
            return false
        }
        
        InsertionLogger.log("AX-APPEND", "Computed updated value (truncated): \(updatedValue.prefix(100)) (length=\(updatedValue.count)), newCursorLocation=\(newCursorLocation)")

        let setError = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        )
        
        if setError != .success {
            InsertionLogger.log("AX-APPEND", "Failed to set AXValue. AXError=\(setError.rawValue)")
            return false
        }
        
        // Verify the value was actually set (critical for Chromium contenteditables)
        var verifyValueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &verifyValueRef) == .success {
            let verifyText: String?
            if let str = verifyValueRef as? String {
                verifyText = str
            } else if let attrStr = verifyValueRef as? NSAttributedString {
                verifyText = attrStr.string
            } else {
                verifyText = nil
            }
            
            if let verifyText = verifyText {
                let matches = verifyText == updatedValue
                InsertionLogger.log("AX-APPEND", "Verified AXValue was set. Matches expected=\(matches), actual (truncated): \(verifyText.prefix(100))")
                
                // Critical fix: if the value didn't actually change, treat as failure
                if !matches {
                    InsertionLogger.log("AX-APPEND", "AX write returned success but value did not change - treating as failure")
                    return false
                }
            } else {
                InsertionLogger.log("AX-APPEND", "Could not verify AXValue - verification value type unknown")
                return false
            }
        } else {
            InsertionLogger.log("AX-APPEND", "Could not verify AXValue - failed to read back")
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
        InsertionLogger.log("CLIPBOARD", "Starting clipboard paste of \(emoji)")
        
        let snapshot = PasteboardSnapshot.capture()
        writeStringToPasteboard(emoji)
        
        // Log what we put on the clipboard
        let pasteboardString = NSPasteboard.general.string(forType: .string) ?? "nil"
        InsertionLogger.log("CLIPBOARD", "Wrote to pasteboard: \(pasteboardString)")

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            InsertionLogger.log("CLIPBOARD", "Failed to create CGEvents")
            snapshot.restore()
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        InsertionLogger.log("CLIPBOARD", "Posting Cmd+V key events")
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Verify the paste actually worked before restoring clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var focusedElementRef: CFTypeRef?
            let systemWideElement = AXUIElementCreateSystemWide()
            
            if AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
               let focusedElementRef,
               let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement?.self) {
                
                var valueRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef) == .success {
                    let currentText: String?
                    if let str = valueRef as? String {
                        currentText = str
                    } else if let attrStr = valueRef as? NSAttributedString {
                        currentText = attrStr.string
                    } else {
                        currentText = nil
                    }
                    
                    if let currentText = currentText {
                        InsertionLogger.log("CLIPBOARD", "After Cmd+V, focused element text (truncated): \(currentText.prefix(100))")
                        // Check if emoji is in the text (simple heuristic)
                        let containsEmoji = currentText.contains(emoji)
                        InsertionLogger.log("CLIPBOARD", "Emoji \(emoji) found in text after paste: \(containsEmoji)")
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            InsertionLogger.log("CLIPBOARD", "Restoring clipboard after paste")
            snapshot.restore()
        }

        return true
    }
}
