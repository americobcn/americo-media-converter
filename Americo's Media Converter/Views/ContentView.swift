import SwiftUI

struct ContentView: View {
    @Environment(ConverterViewModel.self) private var vm

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 15) {
                FileListView()
                    .frame(maxHeight: .infinity)

                HStack(spacing: 12) {
                    Button("Cancel", action: vm.cancelConversion)
                        .keyboardShortcut(.cancelAction)

                    Button("Convert", action: vm.startConversion)
                        .keyboardShortcut(.defaultAction)
                }
                .buttonStyle(AC3ButtonStyle())
                .disabled(!vm.canConvert)
                .frame(height: 32)
            }
            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 2) {
                PlayerView()
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                ConversionTabsView()
                    .frame(minHeight: 300, maxHeight: .infinity)
            }
            .frame(minWidth: 860, maxWidth: 914, maxHeight: .infinity)
        }
        .padding([.top, .leading, .trailing], 20)
        .padding(.bottom, 12)
        .frame(minWidth: 1400, minHeight: 840)
        .focusedSceneValue(\.converter, vm)
        .onPasteCommand(of: [.fileURL], perform: pasteFiles)
    }

    private func pasteFiles(_ providers: [NSItemProvider]) {
        Task {
            vm.addMediaFiles(await providers.loadFileURLs())
        }
    }
}
