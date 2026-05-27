import Combine
import SwiftUI

struct TopBarView: View {
    @ObservedObject var appState: AppState

    let openPicker: () -> Void
    let showStatistics: () -> Void
    let showCustomEmoji: () -> Void

    private let refreshTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Emoji Picker")
                    .font(.title2.weight(.semibold))

                Text("Press `§` from any app to open the picker.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                PermissionRow(
                    title: "Accessibility",
                    isEnabled: appState.hasAccessibility,
                    detail: "Needed to insert emoji directly into focused text fields."
                )

                PermissionRow(
                    title: "Input Monitoring",
                    isEnabled: appState.hasInputMonitoring && appState.hotkeyCaptureAvailable,
                    detail: "Needed to catch `§` globally and prevent the raw key from being typed."
                )
            }

            if !appState.hasAccessibility || !appState.hasInputMonitoring || !appState.hotkeyCaptureAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    if !appState.hasAccessibility {
                        Button("Grant Accessibility") {
                            appState.requestAccessibilityPermission()
                        }
                    }

                    if !appState.hasInputMonitoring || !appState.hotkeyCaptureAvailable {
                        Button("Grant Input Monitoring") {
                            appState.requestInputMonitoringPermission()
                        }
                    }

                    Button("Refresh Permissions") {
                        appState.refreshAll()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { appState.launchAtLoginEnabled },
                        set: { appState.setLaunchAtLoginEnabled($0) }
                    )
                )

                Text(appState.launchAtLoginStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("Open Picker", action: openPicker)
                    .buttonStyle(.borderedProminent)

                Button("Statistics", action: showStatistics)
                    .buttonStyle(.bordered)
            }

            Button("Manage Custom Emoji", action: showCustomEmoji)
                .buttonStyle(.bordered)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            appState.refreshAll()
        }
        .onReceive(refreshTimer) { _ in
            appState.refreshAll()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let isEnabled: Bool
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(isEnabled ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
