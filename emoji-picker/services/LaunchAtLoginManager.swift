import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    func apply(desiredEnabled: Bool) -> String {
        guard #available(macOS 13.0, *) else {
            return "Launch at login requires macOS 13 or newer."
        }

        let service = SMAppService.mainApp

        do {
            if desiredEnabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            return "Launch at login update failed: \(error.localizedDescription)"
        }

        return statusMessage(desiredEnabled: desiredEnabled)
    }

    func statusMessage(desiredEnabled: Bool) -> String {
        guard #available(macOS 13.0, *) else {
            return "Launch at login requires macOS 13 or newer."
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return "Launch at login is enabled."
        case .requiresApproval:
            return "Launch at login is waiting for macOS approval."
        case .notFound:
            return "Launch at login service was not found in the signed app."
        case .notRegistered:
            return desiredEnabled ? "Launch at login is not registered yet." : "Launch at login is disabled."
        @unknown default:
            return "Launch at login status is unknown."
        }
    }
}
