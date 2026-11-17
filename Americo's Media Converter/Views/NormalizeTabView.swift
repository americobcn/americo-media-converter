import SwiftUI

struct NormalizeTabView: View {
    @Environment(ConverterViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 12) {
            LabeledControl(title: "Target LUFS") {
                Picker("Target LUFS", selection: $vm.normalizeTarget) {
                    ForEach(LUFSTarget.allCases) { target in
                        Text(target.title).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 514)
            }

            LogView(tab: .normalize)
        }
        .padding(17)
    }
}
