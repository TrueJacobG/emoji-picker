import AppKit
import Combine
import CoreGraphics

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var hasAccessibility = false
    @Published private(set) var hasInputMonitoring = false
    @Published private(set) var hotkeyCaptureAvailable = false
    @Published private(set) var launchAtLoginStatusText = ""
    @Published var launchAtLoginEnabled: Bool

    private weak var hotkeyService: HotkeyService?
    private let settings = AppSettings.shared
    private let launchAtLoginManager = LaunchAtLoginManager()

    init() {
        launchAtLoginEnabled = settings.launchAtLoginEnabled
        refreshAll()
    }

    func attach(hotkeyService: HotkeyService) {
        self.hotkeyService = hotkeyService
    }

    func refreshAll() {
        hasAccessibility = AXIsProcessTrusted()
        hasInputMonitoring = CGPreflightListenEventAccess()
        hotkeyService?.refreshRegistration()
        hotkeyCaptureAvailable = hotkeyService?.isRunning ?? false
        launchAtLoginEnabled = settings.launchAtLoginEnabled
        launchAtLoginStatusText = launchAtLoginManager.statusMessage(desiredEnabled: launchAtLoginEnabled)
    }

    func requestInitialPermissions() {
        requestAccessibilityPermission()
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestInputMonitoringPermission() {
        let granted = CGRequestListenEventAccess()
        hotkeyService?.refreshRegistration()
        refreshAll()

        guard !granted else {
            return
        }

        // If macOS doesn't show the consent dialog (common after a prior deny),
        // send the user directly to the Input Monitoring settings pane.
        openSystemSettings(urlStrings: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ])
    }

    func setHotkeyCaptureAvailable(_ isAvailable: Bool) {
        hotkeyCaptureAvailable = isAvailable
        hasInputMonitoring = CGPreflightListenEventAccess()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginEnabled = enabled
        settings.launchAtLoginEnabled = enabled
        launchAtLoginStatusText = launchAtLoginManager.apply(desiredEnabled: enabled)
    }

    func applyLaunchAtLoginPreference() {
        launchAtLoginStatusText = launchAtLoginManager.apply(desiredEnabled: launchAtLoginEnabled)
    }

    private func openSystemSettings(urlStrings: [String]) {
        for urlString in urlStrings {
            guard let url = URL(string: urlString) else {
                continue
            }

            if NSWorkspace.shared.open(url) {
                break
            }
        }
    }
}
