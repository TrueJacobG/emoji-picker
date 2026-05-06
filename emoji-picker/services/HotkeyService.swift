import AppKit
import CoreGraphics

final class HotkeyService {
    static let activationKeyCode = CGKeyCode(10)

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let onHotkey: @MainActor () -> Void
    private let onAvailabilityChanged: @MainActor (Bool) -> Void

    private(set) var isRunning = false

    init(
        onHotkey: @escaping @MainActor () -> Void,
        onAvailabilityChanged: @escaping @MainActor (Bool) -> Void
    ) {
        self.onHotkey = onHotkey
        self.onAvailabilityChanged = onAvailabilityChanged
    }

    deinit {
        stop()
    }

    func start() {
        stop()

        guard CGPreflightListenEventAccess() else {
            reportAvailability(false)
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleEvent(type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            reportAvailability(false)
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        isRunning = true

        reportAvailability(true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        isRunning = false
        reportAvailability(false)
    }

    func refreshRegistration() {
        let shouldRun = CGPreflightListenEventAccess()

        if shouldRun && !isRunning {
            start()
        } else if !shouldRun && isRunning {
            stop()
        } else {
            reportAvailability(isRunning)
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1

            guard keyCode == Self.activationKeyCode, !isRepeat else {
                return Unmanaged.passUnretained(event)
            }

            DispatchQueue.main.async { [onHotkey] in
                onHotkey()
            }

            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func reportAvailability(_ isAvailable: Bool) {
        DispatchQueue.main.async { [onAvailabilityChanged] in
            onAvailabilityChanged(isAvailable)
        }
    }
}
