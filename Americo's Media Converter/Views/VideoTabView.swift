import SwiftUI

struct VideoTabView: View {
    @Environment(ConverterViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                LabeledControl(title: "Codec") {
                    Picker("Codec", selection: $vm.videoCodec) {
                        ForEach(VideoCodecs.allCases) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                LabeledControl(title: "Profile") {
                    Picker("Profile", selection: $vm.videoProfileTitle) {
                        ForEach(vm.videoProfileOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 149)
                }

                LabeledControl(title: "Resolution") {
                    Picker("Resolution", selection: $vm.videoResolution) {
                        ForEach(VideoResolution.allCases) { resolution in
                            Text(resolution.resolutionString).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 139)
                }

                LabeledControl(title: "FPS") {
                    Picker("FPS", selection: $vm.videoFrameRate) {
                        ForEach(VideoFrameRates.allCases) { rate in
                            Text(rate.displayName).tag(rate)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 173)
                }

                LabeledControl(title: "Container") {
                    Picker("Container", selection: $vm.videoContainer) {
                        ForEach(vm.videoContainerOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 92)
                }

                Toggle("Pad", isOn: $vm.videoPad)
                    .padding(.top, 20)
            }

            LogView(tab: .video)
        }
        .padding(17)
    }
}
