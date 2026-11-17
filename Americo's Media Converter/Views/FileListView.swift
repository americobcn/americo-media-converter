import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    @Environment(ConverterViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        Group {
            if vm.files.isEmpty {
                ContentUnavailableView("Drop Media Files",
                                       systemImage: "tray.and.arrow.down",
                                       description: Text("Drag files from Finder or paste them with ⌘V."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                    .contentShape(.rect)
                    .dropDestination(for: URL.self, action: addDroppedFiles)
            } else {
                List(selection: $vm.selection) {
                    ForEach(vm.files) { file in
                        FileRowView(file: file)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    .onMove(perform: vm.move)
                    .onInsert(of: [.fileURL], perform: insertFiles)
                }
                .listStyle(.plain)
                .dropDestination(for: URL.self, action: addDroppedFiles)
            }
        }
        .onChange(of: vm.selection) {
            vm.selectionChanged()
        }
        .overlay {
            if vm.isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Processing ^[\(vm.loadingCount) file](inflect: true)…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
            }
        }
    }

    private func addDroppedFiles(_ urls: [URL], _ location: CGPoint) -> Bool {
        vm.addMediaFiles(urls)
        return true
    }

    private func insertFiles(at index: Int, _ providers: [NSItemProvider]) {
        Task {
            vm.addMediaFiles(await providers.loadFileURLs())
        }
    }
}
