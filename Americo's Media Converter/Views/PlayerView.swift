import SwiftUI

struct PlayerView: NSViewRepresentable {
    @Environment(ConverterViewModel.self) private var vm

    func makeNSView(context: Context) -> MPVPlayerView {
        vm.player
    }

    func updateNSView(_ nsView: MPVPlayerView, context: Context) {
    }
}
