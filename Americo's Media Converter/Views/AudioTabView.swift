import SwiftUI

struct AudioTabView: View {
    @Environment(ConverterViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                LabeledControl(title: "Type") {
                    Picker("Type", selection: $vm.audioType) {
                        ForEach(AudioTypes.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 138)
                }

                LabeledControl(title: vm.audioBitsLabel) {
                    Picker(vm.audioBitsLabel, selection: $vm.audioBits) {
                        ForEach(vm.audioBitsOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 149)
                }

                LabeledControl(title: "Sample Rate") {
                    Picker("Sample Rate", selection: $vm.audioSampleRate) {
                        ForEach(vm.audioSampleRateOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 159)
                }
            }

            LogView(tab: .audio)
        }
        .padding(17)
    }
}
