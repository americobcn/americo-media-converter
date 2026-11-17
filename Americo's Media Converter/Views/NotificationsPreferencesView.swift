import SwiftUI

struct NotificationsPreferencesView: View {
    private let prefs = PreferencesManager.shared
    @State private var isNotificationsEnabled: Bool

    init() {
        _isNotificationsEnabled = State(initialValue: PreferencesManager.shared.isNotificationsEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Form {
                Toggle("Enable Notifications", isOn: $isNotificationsEnabled)

                Text(isNotificationsEnabled ? "Notifications are enabled for this app" : "Notifications are disabled")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: isNotificationsEnabled) {
            prefs.isNotificationsEnabled = isNotificationsEnabled
        }
    }
}
