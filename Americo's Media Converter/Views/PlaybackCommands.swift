import SwiftUI

struct PlaybackCommands: Commands {
    @FocusedValue(\.converter) private var vm

    var body: some Commands {
        CommandMenu("Media") {
            Button("Remove Selected Files", action: deleteSelected)
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(vm?.hasSelection != true)
        }
    }

    private func deleteSelected() {
        vm?.deleteSelected()
    }
}
