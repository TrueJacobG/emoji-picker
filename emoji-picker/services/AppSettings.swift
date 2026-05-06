import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let userDefaults = UserDefaults.standard
    private let launchAtLoginKey = "launchAtLoginEnabled"

    private init() {
        userDefaults.register(defaults: [launchAtLoginKey: true])
    }

    var launchAtLoginEnabled: Bool {
        get { userDefaults.bool(forKey: launchAtLoginKey) }
        set { userDefaults.set(newValue, forKey: launchAtLoginKey) }
    }
}
