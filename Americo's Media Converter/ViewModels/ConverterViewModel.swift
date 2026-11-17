import Cocoa
import SwiftUI

@MainActor
@Observable
final class ConverterViewModel: ConverterDelegate {

    // MARK: - File List State
    var files: [MediaFile] = []
    var selection: Set<MediaFile.ID> = []
    var isLoading = false
    var loadingCount = 0


    // MARK: - Tab State
    var selectedTab: ConversionTab = .video {
        didSet { resetAllProgress() }
    }


    // MARK: - Logs
    var audioLog: [LogEntry] = []
    var videoLog: [LogEntry] = []
    var normalizeLog: [LogEntry] = []


    // MARK: - Audio Settings
    var audioType: AudioTypes = .WAV {
        didSet { audioTypeChanged() }
    }
    var audioBits: String = AudioBitDepth.b24.bitDepth
    var audioSampleRate: String = AudioSampleRate.f48khz.frequency


    // MARK: - Video Settings
    var videoCodec: VideoCodecs = .ProRes {
        didSet { videoCodecChanged() }
    }
    var videoProfileTitle: String = VideoProfiles.ProRes.profiles[0].title
    var videoResolution: VideoResolution = .hd1080
    var videoFrameRate: VideoFrameRates = .auto
    var videoContainer: String = VideoContainers.ProRes.containers[0]
    var videoPad = false


    // MARK: - Normalize Settings
    var normalizeTarget: LUFSTarget = .ebuR128


    // MARK: - Services
    @ObservationIgnored let player = MPVPlayerView(frame: .zero)
    @ObservationIgnored let mc = MediaController()
    @ObservationIgnored private let prefs = PreferencesManager.shared
    @ObservationIgnored private var cv: Converter!
    @ObservationIgnored private var conversionType: ConversionTab?
    @ObservationIgnored private var keyMonitor: Any?


    // MARK: - Initializer
    init() {
        cv = Converter(delegate: self)
        installSpaceKeyMonitor()
    }


    // MARK: - Keyboard
    private func installSpaceKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            nonisolated(unsafe) let event = event
            let handled = MainActor.assumeIsolated {
                guard let self, self.shouldTogglePlayback(for: event) else { return false }
                self.togglePlayPause()
                return true
            }
            return handled ? nil : event
        }
    }


    private func shouldTogglePlayback(for event: NSEvent) -> Bool {
        guard event.keyCode == 49,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function]).isEmpty,
              let window = event.window,
              window === player.window else { return false }
        if let textView = window.firstResponder as? NSTextView, textView.isEditable {
            return false
        }
        return true
    }


    // MARK: - Derived State
    var canConvert: Bool {
        !files.isEmpty
    }

    var hasSelection: Bool {
        !selection.isEmpty
    }

    func log(for tab: ConversionTab) -> [LogEntry] {
        switch tab {
        case .audio: return audioLog
        case .video: return videoLog
        case .normalize: return normalizeLog
        }
    }

    var audioBitsLabel: String {
        audioType == .WAV ? "Bit Depth" : "Bit Rate"
    }

    var audioBitsOptions: [String] {
        audioType == .WAV ? AudioBitDepth.allCases.map { $0.bitDepth } : AudioBitRates.allCases.map { $0.bitRate }
    }

    var audioSampleRateOptions: [String] {
        audioType == .WAV ? AudioSampleRate.allCases.map { $0.frequency } : [AudioSampleRate.f48khz, AudioSampleRate.f44khz].map { $0.frequency }
    }

    private var videoProfiles: VideoProfiles {
        VideoProfiles(rawValue: videoCodec.rawValue) ?? .ProRes
    }

    var videoProfileOptions: [String] {
        videoProfiles.profiles.map { $0.title }
    }

    var videoContainerOptions: [String] {
        (VideoContainers(rawValue: videoCodec.rawValue) ?? .ProRes).containers
    }


    // MARK: - Settings Changes
    func audioTypeChanged() {
        switch audioType {
        case .WAV:
            audioBits = AudioBitDepth.b24.bitDepth
            audioSampleRate = AudioSampleRate.f48khz.frequency
            break

        case .AAC, .MP3:
            audioBits = AudioBitRates.b320k.bitRate
            audioSampleRate = AudioSampleRate.f48khz.frequency
            break
        }
    }


    func videoCodecChanged() {
        videoProfileTitle = videoProfiles.profiles[0].title
        videoContainer = videoContainerOptions[0]
    }


    // MARK: - File List Actions
    func addMediaFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        loadingCount = urls.count
        isLoading = true
        let mc = self.mc

        Task { [weak self] in
            var newFiles: [MediaFile] = []

            await withTaskGroup(of: MediaFile?.self) { group in
                for url in urls {
                    let path = url.path
                    group.addTask {
                        let mfInfo = await mc.isAVMediaType(url: URL(fileURLWithPath: path))
                        guard mfInfo.isPlayable else { return nil }
                        return MediaFile(mfURL: URL(fileURLWithPath: path), formatDescription: mfInfo.formats)
                    }
                }

                for await result in group {
                    if let file = result {
                        newFiles.append(file)
                    }
                }
            }

            guard let self = self else { return }
            self.files.append(contentsOf: newFiles)
            self.isLoading = false
        }
    }


    func deleteSelected() {
        guard !selection.isEmpty else { return }
        files.removeAll { selection.contains($0.id) }
        selection = []
        player.clear()
    }


    func move(from source: IndexSet, to destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
    }


    func selectionChanged() {
        guard let file = files.first(where: { selection.contains($0.id) }) else {
            player.clear()
            return
        }
        player.load(url: file.mfURL, hasVideo: file.hasVideo)
    }


    func togglePlayPause() {
        player.togglePause()
    }


    // MARK: - Conversion
    func startConversion() {
        audioLog = []
        videoLog = []
        normalizeLog = []

        if files.count < 1 {
            return
        }

        switch selectedTab {
        case .audio:
            resetAllProgress()
            conversionType = .audio
            convertAudio()
            break
        case .video:
            resetAllProgress()
            conversionType = .video
            convertVideo()
            break
        case .normalize:
            resetAllProgress()
            conversionType = .normalize
            convertNormalize()
            break
        }
    }


    func cancelConversion() {
        cv.cancelAllProcesses()
    }


    private func convertAudio() {
        guard let destinationFolder = resolveDestinationFolder(preferred: prefs.defaultAudioDestination) else {
            return
        }

        let newAudioExtension = audioType.fileExt
        let arguments = FFmpegArguments.audio(type: audioType,
                                              bits: audioBits,
                                              sampleRate: audioSampleRate,
                                              aacCodec: Constants.aacCodec)

        audioLog = []
        for (idx, file) in files.enumerated() {
            let outPath = composeFileURL(of: file.mfURL, to: newAudioExtension, destinationFolder)
            cv.convert(file: file, args: arguments, outPath: outPath, row: idx) {
                success, message, exitCode in
                if success {
                    self.progressBarCompleted(idx)
                } else {
                    self.progressBarError(idx)
                }
            }
        }
    }


    private func convertVideo() {
        guard let destinationFolder = resolveDestinationFolder(preferred: prefs.defaultVideoDestination) else {
            return
        }

        let arguments = FFmpegArguments.video(codec: videoCodec,
                                              profileTitle: videoProfileTitle,
                                              resolution: videoResolution,
                                              frameRate: videoFrameRate,
                                              pad: videoPad,
                                              hasLibx264: Constants.hasLibx264,
                                              aacCodec: Constants.aacCodec)

        let newVideoExtension = videoContainer.lowercased()
        for (idx, file) in files.enumerated() {
            videoLog.append(LogEntry(text: "Converting \(file.mfURL)\n", kind: .regular))
            let outPath = composeFileURL(of: file.mfURL, to: newVideoExtension, destinationFolder)
            cv.convert(file: file, args: arguments, outPath: outPath, row: idx) {
                success, message, exitCode in
                if success {
                    self.progressBarCompleted(idx)
                } else {
                    self.progressBarError(idx)
                }
            }
        }
    }


    private func convertNormalize() {
        let targetLUFS = normalizeTarget.value

        normalizeLog = []

        guard let destinationFolder = resolveDestinationFolder(preferred: prefs.defaultAudioDestination) else {
            return
        }

        for (idx, file) in files.enumerated() {
            cv.normalize(file: file, targetLUFS: targetLUFS, row: idx, destinationFolder: destinationFolder) { success, _, _ in
                if !success { self.progressBarError(idx) }
            }
        }
    }


    // MARK: - Destination Helpers
    private func resolveDestinationFolder(preferred: String) -> String? {
        if preferred.isEmpty {
            return chooseFolderDestination()
        } else {
            if checkDestinationPath(destPath: preferred) {
                return preferred
            } else {
                return chooseFolderDestination()
            }
        }
    }


    func chooseFolderDestination() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to save files"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK,
            let selectedURL = panel.urls.first {
            return selectedURL.path
        } else {
            return nil
        }
    }


    private func checkDestinationPath(destPath: String) -> Bool {
        let directoryURL = URL(fileURLWithPath: destPath)
        do {
            let resourceValues = try directoryURL.resourceValues(forKeys: [.isDirectoryKey, .isWritableKey])
            if (resourceValues.isDirectory != nil && resourceValues.isWritable != nil)  {
                return true
            }
        } catch {
            Constants.dropAlert(message: "Destination path in preferences is not available or writable.",
                                informative: "Choose a valid folder.")
        }
        return false
    }


    private func composeFileURL(of filePath: URL, to newExtension: String, _ destinationFolder: String?) -> String {
        if destinationFolder != nil {
            let url = URL(fileURLWithPath: destinationFolder! + "/" + filePath.lastPathComponent)
            let newUrl = url.deletingPathExtension().appendingPathExtension(newExtension)
            return newUrl.path
        }

        let newUrl = filePath.deletingPathExtension().appendingPathExtension(newExtension)
        return newUrl.path
    }


    // MARK: - Progress
    func resetAllProgress() {
        for idx in files.indices {
            files[idx].progress = 0.0
            files[idx].hasError = false
            files[idx].isProgressVisible = false
        }
    }


    private func progressBarCompleted(_ row: Int) {
        guard files.indices.contains(row) else { return }
        files[row].progress = 100.0
    }


    private func progressBarError(_ row: Int) {
        guard files.indices.contains(row) else { return }
        files[row].hasError = true
    }


    // MARK: - ConverterDelegate
    func appendLog(_ text: String, _ kind: LogKind) {
        let entry = LogEntry(text: text, kind: kind)
        switch conversionType {
        case .audio:
            audioLog.append(entry)
            break
        case .video:
            videoLog.append(entry)
            break
        case .normalize:
            normalizeLog.append(entry)
            break
        default:
            break
        }
    }


    func showProgressBar(_ row: Int) {
        guard files.indices.contains(row) else { return }
        files[row].isProgressVisible = true
    }


    func conversionProgress(forRow row: Int, _ percent: Double) {
        guard files.indices.contains(row) else { return }
        files[row].progress = percent
    }
}
