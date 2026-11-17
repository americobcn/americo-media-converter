import SwiftUI

struct GeneralPreferencesView: View {
    private let prefs = PreferencesManager.shared
    @State private var videoDestination: String
    @State private var audioDestination: String

    init() {
        _videoDestination = State(initialValue: PreferencesManager.shared.defaultVideoDestination)
        _audioDestination = State(initialValue: PreferencesManager.shared.defaultAudioDestination)
    }

    var body: some View {
        VStack {
            Form {
                TextField("Video destination:", text: $videoDestination, prompt: Text("Path to folder"))
                TextField("Audio destination:", text: $audioDestination, prompt: Text("Path to folder"))
            }

            Spacer()

            HStack {
                Spacer()
                Button("Reset to Defaults", action: resetToDefaults)
            }
        }
        .padding(20)
        .onChange(of: videoDestination) {
            prefs.defaultVideoDestination = videoDestination
        }
        .onChange(of: audioDestination) {
            prefs.defaultAudioDestination = audioDestination
        }
    }

    private func resetToDefaults() {
        prefs.resetToDefaults()
        videoDestination = prefs.defaultVideoDestination
        audioDestination = prefs.defaultAudioDestination
    }
}
