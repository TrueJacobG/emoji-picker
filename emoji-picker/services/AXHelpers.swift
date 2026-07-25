import ApplicationServices

struct AXHelpers {
    static func createSystemWideElement() -> AXUIElement {
        AXUIElementCreateSystemWide()
    }
    
    static func captureFocusedElement() -> AXUIElement? {
        let systemWide = createSystemWideElement()
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
    
    static func getFocusedElement(from systemWide: AXUIElement) -> CFTypeRef? {
        var elementRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &elementRef
        )
        
        guard result == .success else {
            return nil
        }
        
        return elementRef
    }
    
    static func getAttributeValue(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &valueRef
        )
        
        guard result == .success else {
            return nil
        }
        
        return valueRef
    }
    
    static func verifyAttributeValue(_ attribute: String, from element: AXUIElement) -> (success: Bool, value: CFTypeRef?) {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &valueRef
        )
        
        return (success: result == .success, value: valueRef)
    }
    
    static func verifyValueWasSet(_ expectedValue: String, for element: AXUIElement) -> Bool {
        let verification = verifyAttributeValue(kAXValueAttribute, from: element)
        guard verification.success, let verifyValueRef = verification.value else {
            return false
        }
        
        let verifyText: String?
        if let str = verifyValueRef as? String {
            verifyText = str
        } else if let attrStr = verifyValueRef as? NSAttributedString {
            verifyText = attrStr.string
        } else {
            verifyText = nil
        }
        
        guard let verifyText = verifyText else {
            return false
        }
        
        let matches = verifyText == expectedValue
        return matches
    }
    
    static func convertToAXUIElement(_ ref: CFTypeRef) -> AXUIElement {
        return unsafeBitCast(ref, to: AXUIElement.self)
    }
    
    static func convertToAXValue(_ ref: CFTypeRef) -> AXValue {
        return unsafeBitCast(ref, to: AXValue.self)
    }
    
    static func getValueType(_ value: AXValue) -> AXValueType {
        return AXValueGetType(value)
    }
    
    static func getValue(_ value: AXValue, type: AXValueType, outValue: UnsafeMutableRawPointer) -> Bool {
        return AXValueGetValue(value, type, outValue)
    }
    
    static func getActionNames(for element: AXUIElement) -> [String]? {
        var actionNamesRef: CFArray?
        let result = AXUIElementCopyActionNames(element, &actionNamesRef)
        
        guard result == .success, let actionNamesRef = actionNamesRef else {
            return nil
        }
        
        return actionNamesRef as? [String]
    }
    
    static func getValue(from element: AXUIElement) -> CFTypeRef? {
        var valueRef: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueRef
        )
        
        guard valueError == .success else {
            return nil
        }
        
        return valueRef
    }
    
    static func setValue(_ value: CFTypeRef, for element: AXUIElement) -> Bool {
        let setError = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            value
        )
        
        return setError == .success
    }
    
    static func setFocused(_ element: AXUIElement) -> Bool {
        let setError = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            true as CFTypeRef
        )
        
        return setError == .success
    }
    
    static func performAction(_ action: String, on element: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(element, action as CFString)
        return result == .success
    }
    
    static func getSelectedTextRange(from element: AXUIElement) -> CFTypeRef? {
        var selectedRangeRef: CFTypeRef?
        let rangeError = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        )

        guard rangeError == .success else {
            return nil
        }

        return selectedRangeRef
    }
    
    static func describeAXElement(_ element: AXUIElement?) -> String {
        guard let element = element else {
            return "nil"
        }
        
        var role: CFTypeRef?
        var subrole: CFTypeRef?
        var identifier: CFTypeRef?
        var title: CFTypeRef?
        
        role = getAttributeValue(kAXRoleAttribute, from: element)
        subrole = getAttributeValue(kAXSubroleAttribute, from: element)
        identifier = getAttributeValue(kAXIdentifierAttribute, from: element)
        title = getAttributeValue(kAXTitleAttribute, from: element)
        
        let roleStr = (role as? String) ?? "nil"
        let subroleStr = (subrole as? String) ?? "nil"
        let identifierStr = (identifier as? String) ?? "nil"
        let titleStr = (title as? String) ?? "nil"
        
        return "\(roleStr):\(subroleStr):\(identifierStr):\(titleStr)"
    }
}