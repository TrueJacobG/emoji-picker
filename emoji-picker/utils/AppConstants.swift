import AppKit
import Foundation

struct AppConstants {
    // AX insertion timing constants
    static let refocusDelay: TimeInterval = 0.15
    static let insertionDelay: TimeInterval = 0.1
    static let clipboardRestoreDelay: TimeInterval = 0.3

    // Window positioning
    static let defaultPickerWidth: CGFloat = 460
    static let defaultPickerHeight: CGFloat = 520
    static let popoverWidth: CGFloat = 340
    static let popoverHeight: CGFloat = 380

    // Hotkey: the `§` key on ISO keyboards (keycode 10)
    static let activationKeyCode: CGKeyCode = 10

    // Virtual key for Cmd+V paste (US-layout V)
    static let pasteVirtualKey: CGKeyCode = 9

    // Picker keyboard handler keycodes
    enum KeyCode {
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let arrowDown: UInt16 = 125
        static let arrowUp: UInt16 = 126
    }

    // Permission polling
    static let permissionPollInterval: TimeInterval = 2.0
}
