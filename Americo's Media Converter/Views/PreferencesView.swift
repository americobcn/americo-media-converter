import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralPreferencesView()
            }

            Tab("Notifications", systemImage: "bell") {
                NotificationsPreferencesView()
            }
        }
        .frame(width: 500, height: 350)
        .onExitCommand(perform: closeWindow)
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}
