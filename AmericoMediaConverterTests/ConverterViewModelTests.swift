import Testing
@testable import Americo_s_Media_Converter

@MainActor
struct ConverterViewModelTests {

    @Test func startsOnVideoTabWithDefaults() {
        let vm = ConverterViewModel()
        #expect(vm.selectedTab == .video)
        #expect(vm.audioBits == "24")
        #expect(vm.audioSampleRate == "48000")
        #expect(vm.videoProfileTitle == "HQ")
        #expect(vm.videoContainer == "MOV")
        #expect(vm.normalizeTarget.value == -23)
        #expect(vm.canConvert == false)
    }

    @Test func changingAudioTypeResetsDependentValues() {
        let vm = ConverterViewModel()
        vm.audioType = .MP3
        #expect(vm.audioBitsLabel == "Bit Rate")
        #expect(vm.audioBits == "320")
        #expect(vm.audioBitsOptions.contains(vm.audioBits))
        #expect(vm.audioSampleRateOptions == ["48000", "44100"])

        vm.audioType = .WAV
        #expect(vm.audioBitsLabel == "Bit Depth")
        #expect(vm.audioBits == "24")
        #expect(vm.audioSampleRateOptions == ["96000", "48000", "44100"])
    }

    @Test func changingVideoCodecResetsProfileAndContainer() {
        let vm = ConverterViewModel()
        vm.videoCodec = .DNxHD
        #expect(vm.videoProfileTitle == "HQ")
        #expect(vm.videoContainer == "MXF")
        #expect(vm.videoContainerOptions == ["MXF", "MOV"])

        vm.videoCodec = .H264
        #expect(vm.videoProfileTitle == "High")
        #expect(vm.videoContainer == "MP4")
    }

    @Test func lufsTargetsMatchOriginalValues() {
        #expect(LUFSTarget.allCases.map(\.value) == [-23, -16, -14, -12, -24])
    }
}
