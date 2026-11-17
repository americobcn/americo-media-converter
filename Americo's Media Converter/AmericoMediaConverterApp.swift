import SwiftUI

@main
struct AmericoMediaConverterApp: App {
    @State private var vm = ConverterViewModel()

    var body: some Scene {
        Window("Américo's Media Converter", id: "main") {
            ContentView()
                .environment(vm)
        }
        .defaultSize(width: 1920, height: 1034)
        .windowResizability(.contentMinSize)
        .commands {
            PlaybackCommands()
        }

        Settings {
            PreferencesView()
        }
    }
}
