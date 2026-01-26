import Cocoa
import AVFoundation
import AVKit

struct mediaFile: @unchecked Sendable {
    var mfURL: URL
    var formatDescription: [String: Any] = [:]
}

private struct UserInterfaceIdentifiers {
    static let fileColumnIdentifier = NSUserInterfaceItemIdentifier("fileColumn")
    static let urlColumnIdentifier = NSUserInterfaceItemIdentifier(rawValue: "urlColumn")
    static let fileCellIdentifier = NSUserInterfaceItemIdentifier("fileCell")
}


class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTabViewDelegate, ConverterDelegate {
    
    // MARK: Views Outlets
    @IBOutlet weak var filesTableView: NSTableView!
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var startConversionButton: NSButton!
    @IBOutlet weak var cancelConversionButton: NSButton!
    @IBOutlet weak var converterTabView: NSTabView!
    @IBOutlet weak var audioTabView: NSTabViewItem!
    @IBOutlet weak var videoTabView: NSTabViewItem!
    
    
    // MARK: Audio Outlets
    @IBOutlet weak var audioOutTextView: NSTextView!
    @IBOutlet weak var audioOutScrollView: NSScrollView!
    @IBOutlet weak var audioTypeLabel: NSTextField!
    @IBOutlet weak var audioBitsLabel: NSTextField!
    @IBOutlet weak var audioFrequencyLabel: NSTextField!
    @IBOutlet weak var audioTypeButton:NSPopUpButton!
    @IBOutlet weak var audioBitsButton:NSPopUpButton!
    @IBOutlet weak var audioFrequencyButton:NSPopUpButton!

    
    // MARK: Video Outlets
    @IBOutlet weak var videoOutTextView: NSTextView!
    @IBOutlet weak var videoOutScrollView: NSScrollView!
    @IBOutlet weak var videoCodecButton:NSPopUpButton!
    @IBOutlet weak var videoProfileButton:NSPopUpButton!
    @IBOutlet weak var videoResolutionButton:NSPopUpButton!
    @IBOutlet weak var videoContainerButton:NSPopUpButton!
    @IBOutlet weak var videoFPSButton:NSPopUpButton!
    @IBOutlet weak var videoPadButton: NSButton!
    
        
    // MARK: Media related variables
    
    
    var files: [mediaFile] = []
    let mc = MediaController()
    var movieDepth: CFPropertyList?
    
    // MARK: Loading Status UI
    private var loadingStatusLabel: NSTextField?
    private var loadingIndicator: NSProgressIndicator?
    private var loadingContainerView: NSView?
    
    private(set) var selectedVideoCodec: VideoCodecs = .ProRes
    private(set) var selectedVideoCodecProfile: VideoProfiles = .ProRes
    private(set) var selectedVideoResolution: VideoResolution = .hd1080
    private(set) var selectedVideoFrameRate: VideoFrameRates = .auto
    private(set) var selectedVideoContainer: VideoContainers = .ProRes
    
    private(set) var selectedAudioType: AudioTypes = .WAV
    private(set) var selectedAudioBit: AudioBitDepth = .b24
    private(set) var selectedAudioSampleRate: AudioSampleRate = .f48khz
    
    
    var newAudioExtension: String = ""
    var newVideoExtension: String = ""
    var cv: Converter!
    var conversionType: Constants.ConversionType!
    let prefs = PreferencesManager.shared
    
    
    // MARK: PopUp Button titles
    enum VideoResolution: CaseIterable, Identifiable {
            case sd480, sd576
            case hd720, hd1080
            case cinema2K, cinema4K, cinema5K
            case uhd4K, uhd8K
        
        var id: Self { return self }
        
        var size: (width: Int, height: Int) {
            switch self {
            case .sd480: return (720, 480)
            case .sd576: return (720, 576)
            case .hd720: return (1280, 720)
            case .hd1080: return (1920, 1080)
            case .cinema2K: return (2048, 1080)
            case .cinema4K: return (4096, 2160)
            case .cinema5K: return (5120,2700)
            case .uhd4K: return (3840, 2160)
            case .uhd8K: return (7680, 4320)
            }
        }
        
        var description: String {
            return "\(self.id) - \(size.width)x\(size.height)"
        }
        
        var resolutionString: String {
            return "\(size.width)x\(size.height)"
        }
        
        var ffmpegString: String {
            return "\(size.width):\(size.height)"
        }
    }
    
    enum VideoContainers:  CaseIterable {
        case ProRes, DNxHD, H264
                
        var containers: [String] {
            switch self {
            case .ProRes: return ["MOV", "MXF", "MKV"]
            case .DNxHD: return ["MXF", "MOV"]
            case .H264: return ["MP4", "MOV", "MKV"]
            }
        }
    }
    
    enum VideoCodecs: String, CaseIterable, Identifiable {
        case ProRes, DNxHD, H264
        
        var id: Self { return self }
        
        var codec: String {
            switch self {
            case .ProRes: return "prores_ks"
            case .DNxHD: return "dnxhd"
            case .H264: return "libx264"
            }
        }
    }

    
    enum VideoProfiles: String, CaseIterable, Identifiable {
        case ProRes, DNxHD, H264
        
        var id: Self { return self }
        
        var profiles: [(title: String, profile: String)] {
            switch self {
            case .ProRes: return [("HQ", "3"), ("LT", "1"), ("Standard", "2"), ("4444", "4")]
            case .DNxHD: return [("HQ", "dnxhr_hq"), ("Standard", "dnxhr_sq"), ("HQ 10 bits", "dnxhr_hqx"), ("HQ 4:4:4", "dnxhr_444")]
            case .H264: return [("High", "high"), ("Main", "main"), ("Baseline", "baseline")]
            }
        }
    }
    
    
    /// Common professional video frame rates used in broadcast, cinema, and streaming.
    enum VideoFrameRates: Double, CaseIterable, Identifiable {
        case auto = 0.0
        case fps23_976 = 23.976
        case fps24     = 24.0
        case fps25     = 25.0
        case fps29_97  = 29.97
        case fps30     = 30.0
        case fps48     = 48.0
        case fps50     = 50.0
        case fps59_94  = 59.94
        case fps60     = 60.0
        case fps90     = 90.0
        case fps100    = 100.0
        case fps119_88 = 119.88
        case fps120    = 120.0

        var id: Double { rawValue }

        /// A human-readable label (e.g. “23.976 fps”).
        var displayName: String {
            switch self {
            case .auto:      return "Auto"
            case .fps23_976: return "23.976 fps (NTSC Film)"
            case .fps24:     return "24 fps (Cinema)"
            case .fps25:     return "25 fps (PAL)"
            case .fps29_97:  return "29.97 fps (NTSC)"
            case .fps30:     return "30 fps (Digital)"
            case .fps48:     return "48 fps (HFR Cinema)"
            case .fps50:     return "50 fps (PAL HFR)"
            case .fps59_94:  return "59.94 fps (NTSC HFR)"
            case .fps60:     return "60 fps (Digital HFR)"
            case .fps90:     return "90 fps (VR)"
            case .fps100:    return "100 fps (Broadcast HFR)"
            case .fps119_88: return "119.88 fps (NTSC 120p)"
            case .fps120:    return "120 fps (HFR / Gaming)"
            }
        }
        
        /// Returns the matching enum for a given display name.
        static func fromDisplayName(_ name: String) -> VideoFrameRates? {
            return allCases.first { $0.displayName == name }
        }
    }

    
    enum AudioTypes: String, CaseIterable, Identifiable {
        case WAV, MP3, AAC
        
        var id: Self { return self }
        
        var fileExt: String {
            switch self {
            case .WAV: return "wav"
            case .MP3: return "mp3"
            case .AAC: return "m4a"
            }
        }
    }
    
    
    enum AudioBitDepth: String, CaseIterable, Identifiable {
        case b32, b24, b16
        
        var id: Self { return self }
        
        var bitDepth: String {
            switch self {
            case .b32: return "32"
            case .b24: return "24"
            case .b16: return "16"
            }
        }
    }
    
    
    enum AudioBitRates: String, CaseIterable, Identifiable {
        case b320k, b256k, b192k, b128k
        
        var id: Self { return self }
        
        var bitRate: String {
            switch self {
            case .b320k: return "320"
            case .b256k: return "256"
            case .b192k: return "192"
            case .b128k: return "128"
            }
        }
    }
    
    
    enum AudioSampleRate: String, CaseIterable, Identifiable {
        case f96khz, f48khz, f44khz
        var id: Self { return self }
        var frequency: String {
            switch self {
            case .f96khz: return "96000"
            case .f48khz: return "48000"
            case .f44khz: return "44100"
            }
        }
    }

    // MARK: Initializers
    required init?(coder: NSCoder) {
        super.init(coder: coder)        
        cv = Converter(delegate: self)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupPlayerView()
        setupOutputView()
        setupConverterView()
    }
    
    
    // MARK: Views setup
    func setupPlayerView() {
        playerView.wantsLayer = true
        playerView.showsFrameSteppingButtons = true
        playerView.player = AVPlayer()
    }
    
    
    func setupOutputView() {
        audioOutTextView.backgroundColor = .black
        videoOutTextView.backgroundColor = .black
    }
    
    
    func setupConverterView() {
        converterTabView.delegate = self
        cancelConversionButton.isEnabled = false
        startConversionButton.isEnabled = false
        
        // Audio Buttons setup
        audioBitsLabel.stringValue = "Bit Depth"
        audioTypeButton.removeAllItems()
        audioTypeButton.addItems(withTitles: AudioTypes.allCases.map { $0.rawValue })
        audioTypeButton.selectItem(withTitle: selectedAudioType.rawValue)
        audioBitsButton.removeAllItems()
        audioBitsButton.addItems(withTitles: AudioBitDepth.allCases.map { $0.bitDepth })
        audioBitsButton.selectItem(withTitle: selectedAudioBit.bitDepth)
        audioFrequencyButton.removeAllItems()
        audioFrequencyButton.addItems(withTitles: AudioSampleRate.allCases.map { $0.frequency })
        audioFrequencyButton.selectItem(withTitle: selectedAudioSampleRate.frequency)
        
        // Video Buttons setup
        videoCodecButton.removeAllItems()
        videoCodecButton.addItems(withTitles: VideoCodecs.allCases.map { $0.rawValue })
        videoCodecButton.selectItem(withTitle: selectedVideoCodec.rawValue)
        videoProfileButton.removeAllItems()
        videoProfileButton.addItems(withTitles: VideoProfiles.ProRes.profiles.map { $0.title})
        videoProfileButton.selectItem(withTitle: selectedVideoCodecProfile.profiles[0].title)
        videoResolutionButton.removeAllItems()
        videoResolutionButton.addItems(withTitles: VideoResolution.allCases.map { $0.resolutionString })
        videoResolutionButton.selectItem(withTitle: selectedVideoResolution.resolutionString)
        videoFPSButton.removeAllItems()
        videoFPSButton.addItems(withTitles: VideoFrameRates.allCases.map { $0.displayName })
        videoFPSButton.selectItem(withTitle: selectedVideoFrameRate.displayName)
        videoContainerButton.removeAllItems()
        videoContainerButton.addItems(withTitles: VideoContainers.ProRes.containers)
        videoContainerButton.selectItem(withTitle: selectedVideoContainer.containers.first!)
        videoPadButton.state = .off
    }
    
    
    func setupTableView() {
        filesTableView.delegate = self
        filesTableView.dataSource = self
        filesTableView.registerForDraggedTypes([.fileURL])
        filesTableView.allowsMultipleSelection = true
        filesTableView.rowHeight = 60
    }
    
    
    // MARK: - Loading Status
    
    private func showLoadingStatus(fileCount: Int) {
        let containerView = NSView(frame: filesTableView.bounds)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        
        let label = NSTextField(labelWithString: "Processing \(fileCount) file\(fileCount == 1 ? "" : "s")...")
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.frame = NSRect(x: 0, y: containerView.bounds.midY + 10, width: containerView.bounds.width, height: 24)
        label.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        
        let indicator = NSProgressIndicator(frame: NSRect(
            x: containerView.bounds.midX - 16,
            y: containerView.bounds.midY - 26,
            width: 32,
            height: 32
        ))
        indicator.style = .spinning
        indicator.controlSize = .regular
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        indicator.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        
        containerView.addSubview(label)
        containerView.addSubview(indicator)
        filesTableView.superview?.addSubview(containerView)
        
        loadingContainerView = containerView
        loadingStatusLabel = label
        loadingIndicator = indicator
    }
    
    private func hideLoadingStatus() {
        loadingIndicator?.stopAnimation(nil)
        loadingContainerView?.removeFromSuperview()
        loadingContainerView = nil
        loadingStatusLabel = nil
        loadingIndicator = nil
    }
    
    
    //MARK: IBAction Methods
    @IBAction func startConversion(_ sender: NSButton) {
        audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        videoOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        if files.count < 1 {
            cancelConversionButton.isEnabled = false
            return
        }
        
        cancelConversionButton.isEnabled = true
                
        switch converterTabView.selectedTabViewItem?.label {
            case "Audio":
                resetAllProgressBar()
                conversionType = .audio
                convertAudio()
                break
            case "Video":
                resetAllProgressBar()
                conversionType = .video
                convertVideo()
                break
            default:
                break
         }
    }
    
    
    
    @IBAction func cancelConversion(_ sender: NSButton) {
        cv.cancelAllProcesses()
    }
    
    
    func convertAudio() {
        // DEAL WITH FOLDERS DEFAULTS
        var destinationFolder: String?
        if prefs.defaultAudioDestination.isEmpty {
            destinationFolder = chooseFolderDestination()
        } else {
            if checkDestinationPath(destPath: prefs.defaultAudioDestination) {
                destinationFolder = prefs.defaultAudioDestination
            } else {
                destinationFolder = chooseFolderDestination()
            }
        }
        
        if (destinationFolder == nil) {
            return
        }
        
        
        /// Constructing audio conversion arguments
        newAudioExtension = selectedAudioType.fileExt
        var arguments: String = ""
        
        switch  selectedAudioType { //audioTypeButton.title
        case .WAV:
            if audioBitsButton.title == "24" {
                arguments = "-y -sample_fmt s32 -c:a pcm_s\(audioBitsButton.title)le -ar \(audioFrequencyButton.title)"
            } else {
                arguments = "-y -sample_fmt s\(audioBitsButton.title) -c:a pcm_s\(audioBitsButton.title)le -ar \(audioFrequencyButton.title)"
            }
            break
            
        case .AAC:
            let bufferSize = Int(audioBitsButton.title)! * 2
            arguments = "-y -vn -c:a \(Constants.aacCodec) -b:a \(audioBitsButton.title)k -maxrate \(audioBitsButton.title)k -bufsize \(bufferSize)k -ar \(audioFrequencyButton.title)"
            break
            
        case .MP3:
            arguments = "-y -codec:a libmp3lame -b:a \(audioBitsButton.title)k -ar \(audioFrequencyButton.title)"
            break
                    
        }
        
                
        audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        for (idx, file) in files.enumerated() {
            let outPath = composeFileURL(of: file.mfURL, to: newAudioExtension, destinationFolder)
            cv.convert(file: file, args: arguments, outPath: outPath, row: idx) {
                success, message, exitCode in
                if success {
                    //.videoOutTextView.textStorage?.append(NSAttributedString(string: "Succesfully converted \(file.mfURL)\n", attributes: //Constants.MessageAttribute.succesMessageAttributes))
                } else {
                    //.videoOutTextView.textStorage?.append(NSAttributedString(string: "Failed to convert \(file.mfURL)\n", attributes: //Constants.MessageAttribute.errorMessageAttributes))
                    self.progressBarError(idx)
                }
            }
        }
    }
    
    
    
    func convertVideo() {
        // DEAL WITH FOLDERS DEFAULTS
        var destinationFolder: String?
        if prefs.defaultVideoDestination.isEmpty {
            destinationFolder = chooseFolderDestination()
        } else {
            if checkDestinationPath(destPath: prefs.defaultVideoDestination) {
                destinationFolder = prefs.defaultVideoDestination
            } else {
                destinationFolder = chooseFolderDestination()
            }
        }
        
        if destinationFolder == nil {
            return
        }
            
        /// Constructtion of ffmpeg arguments
        var arguments: String = ""
        var resolution: String = ""
        var profile: String = ""
        var pad: String = ""
        
    
        if let prof = selectedVideoCodecProfile.profiles.first(where: { $0.title == videoProfileButton.title })?.profile {
            profile = prof
        }
                
        if let res = VideoResolution.allCases.first(where: { $0.resolutionString == videoResolutionButton.title })?.ffmpegString {
            resolution = res
        }
        
        if videoPadButton.state == .on {
            pad = ",pad=\(resolution):(ow-iw)/2:(oh-ih)/2"
        }
        
        /// Set pixel formats
        var pix_fmt: String
        switch profile {
            case "dnxhr_hqx", "0", "1", "2", "3":
                pix_fmt = "yuv422p10le"
                break
            case "dnxhr_444":
                pix_fmt = "yuv444p10le"
                break
            case "4", "5":
                pix_fmt = "yuva444p10le"
                break
            default:
                pix_fmt = "yuv422p"
        }
        
        /// Set the frame per seconds
        var newFPS: String = ""
        switch selectedVideoFrameRate.rawValue {
        case 0.0:
            newFPS = ""
            break
        case 29.97:
            newFPS = ",fps=30000/1001"
            break
        case 23.976:
            newFPS = ",fps=24000/1001"
            break
        case 59.94:
            newFPS = ",fps=60000/1001"
            break
        default:
                newFPS = ",fps=\(selectedVideoFrameRate.rawValue)"
        }
        
        var videoCodec: String = "-c:v h264"
        if Constants.hasLibx264 {
            videoCodec = "-c:v libx264 -profile:v high422 -preset slow -crf 18"
        }
        
        switch videoCodecButton.title {
        case "ProRes":
            arguments = "-y -c:v prores_ks -profile:v \(profile) -qscale:v 9 -vendor apl0 -pix_fmt \(pix_fmt) -vf scale=\(resolution):force_original_aspect_ratio=decrease\(pad)\(newFPS) -c:a pcm_s24le"
            break
            
        case "H264":
            arguments = "-y \(videoCodec) -vf format=\(pix_fmt),scale=\(resolution):force_original_aspect_ratio=decrease\(pad)\(newFPS) -c:a \(Constants.aacCodec) -b:a 320k"
            break
            
        case "DNxHD":
            arguments = "-y -c:v dnxhd -profile:v \(profile) -pix_fmt \(pix_fmt) -vf scale=\(resolution):force_original_aspect_ratio=decrease\(pad)\(newFPS)  -c:a pcm_s24le"

        default:
            return
        }
        
        newVideoExtension = videoContainerButton.title.lowercased() // Default extension
        for (idx, file) in files.enumerated() {
            // print("MEDIA: \(file.formatDescription)")
            videoOutTextView.textStorage?.append(NSAttributedString(string: "Converting \(file.mfURL)\n", attributes: Constants.MessageAttribute.regularMessageAttributes))
            let outPath = composeFileURL(of: file.mfURL, to: newVideoExtension, destinationFolder)
            cv.convert(file: file, args: arguments, outPath: outPath, row: idx) {
                success, message, exitCode in
                if success {
                    //.videoOutTextView.textStorage?.append(NSAttributedString(string: "Succesfully converted \(file.mfURL)\n", attributes: //Constants.MessageAttribute.succesMessageAttributes))
                } else {
                    //.videoOutTextView.textStorage?.append(NSAttributedString(string: "Failed to convert \(file.mfURL)\n", attributes: //Constants.MessageAttribute.errorMessageAttributes))
                    self.progressBarError(idx)
                }
            }
        }
    }
    
    
    
    @IBAction func audioTypeChanged(_ sender: NSPopUpButton) {
        switch sender.title {
        case "WAV":
            selectedAudioType = .WAV
            audioBitsLabel.stringValue = "Bit Depth"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: AudioBitDepth.allCases.map { $0.bitDepth })
            audioBitsButton.selectItem(withTitle: AudioBitDepth.b24.bitDepth)
            audioFrequencyButton.removeAllItems()
            audioFrequencyButton.addItems(withTitles: AudioSampleRate.allCases.map { $0.frequency })
            audioFrequencyButton.selectItem(withTitle: AudioSampleRate.f48khz.frequency)
            audioFrequencyButton.selectItem(at: 1)
            break
            
        case "AAC":
            selectedAudioType = .AAC
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: AudioBitRates.allCases.map { $0.bitRate })
            audioBitsButton.selectItem(withTitle: AudioBitRates.b320k.bitRate)
            audioFrequencyButton.removeAllItems()
            audioFrequencyButton.addItems(withTitles: [AudioSampleRate.f48khz, AudioSampleRate.f44khz ].map { $0.frequency })
            audioFrequencyButton.selectItem(withTitle: AudioSampleRate.f48khz.frequency)
            break
            
        case "MP3":
            selectedAudioType = .MP3
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: AudioBitRates.allCases.map { $0.bitRate })
            audioBitsButton.selectItem(withTitle: AudioBitRates.b320k.bitRate)
            audioFrequencyButton.removeAllItems()
            audioFrequencyButton.addItems(withTitles: [AudioSampleRate.f48khz, AudioSampleRate.f44khz ].map { $0.frequency })
            audioFrequencyButton.selectItem(withTitle: AudioSampleRate.f48khz.frequency)
            break
            
        default:
            audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: "Something went wrong" , attributes: Constants.MessageAttribute.errorMessageAttributes))
            return
        }
    }
    
    
    @IBAction func videoCodecChanged(_ sender: NSPopUpButton) {
        switch sender.title {
        case "ProRes":
            selectedVideoCodec = .ProRes
            selectedVideoCodecProfile = .ProRes
            selectedVideoContainer = .ProRes
            
            videoProfileButton.removeAllItems()
            videoProfileButton.addItems(withTitles: VideoProfiles.ProRes.profiles.map { $0.title})
            videoProfileButton.selectItem(withTitle: selectedVideoCodecProfile.profiles[0].title)
            
            videoContainerButton.removeAllItems()
            videoContainerButton.addItems(withTitles: VideoContainers.ProRes.containers)
            videoContainerButton.selectItem(withTitle: selectedVideoContainer.containers[0])
            break
            
        case "H264":
            selectedVideoCodec = .H264
            selectedVideoCodecProfile = .H264
            selectedVideoContainer = .H264
            
            videoProfileButton.removeAllItems()
            videoProfileButton.addItems(withTitles: VideoProfiles.H264.profiles.map { $0.title})
            videoProfileButton.selectItem(withTitle: selectedVideoCodecProfile.profiles[0].title)
            
            videoContainerButton.removeAllItems()
            videoContainerButton.addItems(withTitles: VideoContainers.H264.containers)
            videoContainerButton.selectItem(withTitle: selectedVideoContainer.containers[0])
            break
            
        case "DNxHD":
            selectedVideoCodec = .DNxHD
            selectedVideoCodecProfile = .DNxHD
            selectedVideoContainer = .DNxHD
            
            videoProfileButton.removeAllItems()
            videoProfileButton.addItems(withTitles: VideoProfiles.DNxHD.profiles.map { $0.title})
            videoProfileButton.selectItem(withTitle: selectedVideoCodecProfile.profiles[0].title)
            
            videoContainerButton.removeAllItems()
            videoContainerButton.addItems(withTitles: VideoContainers.DNxHD.containers)
            videoContainerButton.selectItem(withTitle: self.selectedVideoContainer.containers[0])
            break
        default:
            break
        }
    }
    
    /// IBAction called when the user changes the frame rate in the NSPopUpButton.
    @IBAction func videoFPSButtonChanged(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem,
              let rate = VideoFrameRates.fromDisplayName(title) else { return }
        selectedVideoFrameRate = rate
        print("Selected Frame Rate: \(rate.displayName) (\(rate.rawValue) fps)")
    }
    
    
    @IBAction func openPreferences(_ sender: NSMenuItem) {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.showPreferences()
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
//                print("The directory exists and we have write permissions.")
                return true
            }
        } catch {
            Constants.dropAlert(message: "Destination path in preferences is not available or writable.",
                                informative: "Choose a valid folder.")
//            print("An error occurred, choosing destination folder.")
        }
        return false
    }
        
    
    
    // MARK:  TableView Datasource Methods
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        return files.count
    }
    
    // NSUserInterfaceItemIdentifier(rawValue: "fileCell")
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let colIdentifier = tableColumn?.identifier else { return nil }
        switch colIdentifier {
        case UserInterfaceIdentifiers.fileColumnIdentifier:
            guard let viewCell = tableView.makeView(withIdentifier: UserInterfaceIdentifiers.fileCellIdentifier, owner: nil ) as? CustomCellView
            else { return nil }
            viewCell.fileNameLabel.stringValue = "\(files[row].mfURL.lastPathComponent) | \(formatSecondsTime(files[row].formatDescription["duration"] as? Double ?? 0.0))"
            viewCell.fileInfoLabel.stringValue = getFormatDescription(row: row)
            if files[row].formatDescription.keys.contains("videoDesc") {
                viewCell.cellImageView.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)
            } else {
                viewCell.cellImageView.image = NSImage(systemSymbolName: "hifispeaker", accessibilityDescription: nil)
            }
            viewCell.progressView.setupAsDeterminateBar()
            
            return viewCell
            
        case UserInterfaceIdentifiers.urlColumnIdentifier:
            guard let viewCell = tableView.makeView(withIdentifier: UserInterfaceIdentifiers.urlColumnIdentifier, owner: self ) as? NSTableCellView
            else { return nil }
            viewCell.textField?.stringValue = files[row].mfURL.path
            return viewCell
            
        default:
            return nil
        }
    }
            
    
    // MARK:  TableView Delegate Methods
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        let selectedRow = tableView.selectedRow
        if selectedRow != -1 {
            let item = AVPlayerItem(url: files[selectedRow].mfURL)
            playerView.player?.replaceCurrentItem(with: item)
            playerView.player?.rate = 0.0
        }
    }
    
    
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
    {
        return files[row].mfURL as NSURL
    }
    
        
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        if info.draggingSource as? NSTableView == tableView {
            // Internal move (row reordering)
            tableView.setDropRow(row, dropOperation: .above)
            return .move
        } else if info.draggingPasteboard.types?.contains(.fileURL) == true {
            // File Drop (from Finder)
            tableView.setDropRow(row, dropOperation: .above)
            return .copy
        }
        return []
    }
    
    
    
    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation)
    -> Bool
    {
        // Moved row on tableview
        if info.draggingSource as? NSTableView == tableView {
            guard let sourceRow = tableView.selectedRowIndexes.first else {
                return false
            }
            
            guard sourceRow < files.count else { return false }            
            // Prevent dropping onto the same row
            guard sourceRow != row else { return false }
            
            let draggedItem = files[sourceRow]
            
            // Adjust the destination index when dragging downwards
            let adjustedIndex = row > sourceRow ? row - 1 : row
            
            files.remove(at: sourceRow)
                        
            files.insert(draggedItem, at: adjustedIndex)
            tableView.moveRow(at: sourceRow, to: adjustedIndex)
            return true
            
        // Dragged files from finder
        } else if info.draggingPasteboard.types?.contains(.fileURL) == true {
            guard let pasteboardObjects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil),
                  !pasteboardObjects.isEmpty else {
                return false
            }
            
            let fileCount = pasteboardObjects.count
            showLoadingStatus(fileCount: fileCount)
            
            Task { [weak self] in
                guard let self = self else { return }
                
                var newFiles: [mediaFile] = []
                
                await withTaskGroup(of: mediaFile?.self) { group in
                    for object in pasteboardObjects {
                        guard let url = object as? NSURL,
                              let path = url.path else { continue }
                        
                        group.addTask { [weak self] in
                            guard let self = self else { return nil }
                            let mfInfo = await self.mc.isAVMediaType(url: URL(fileURLWithPath: path))
                            guard mfInfo.isPlayable else { return nil }
                            return mediaFile(mfURL: URL(fileURLWithPath: path), formatDescription: mfInfo.formats)
                        }
                    }
                    
                    for await result in group {
                        if let file = result {
                            newFiles.append(file)
                        }
                    }
                }
                
                self.files.append(contentsOf: newFiles)
                self.hideLoadingStatus()
                self.filesTableView.reloadData()
                self.cancelConversionButton.isEnabled = !self.files.isEmpty
                self.startConversionButton.isEnabled = !self.files.isEmpty
            }
            
            return true
        }
        
        return false
    }
    
    
    
    // MARK: Keyboard event handlers
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
            case 51:
                deleteSelectedRow()
                if (files.count == 0) {
                    startConversionButton.isEnabled = false
                    cancelConversionButton.isEnabled = false
                }
                break
            case 49:
                playPause()
                break
            default:
                super.keyDown(with: event)
        }
    }
    
    
    
    private func playPause() {
        guard let rate = playerView.player?.rate else { return }
        if rate == 0.0  {
            playerView.player?.play()
        } else {
            playerView.player?.pause()
        }
    }
    
    
    
    private func deleteSelectedRow() {
        let selectedIndexes = filesTableView.selectedRowIndexes
        // Ensure there is something to delete
        guard !selectedIndexes.isEmpty else { return }
        
        // Convert to an array and delete items from the data source
        let indexesToRemove = selectedIndexes.sorted(by: >) // Sort in descending order
        for index in indexesToRemove {
            files.remove(at: index)
        }
    
        filesTableView.removeRows(at: selectedIndexes, withAnimation: .effectFade)
        playerView.player?.rate = 0.0
        playerView.player?.replaceCurrentItem(with: nil)
    }
    
    
    
    // MARK: ConverterDelegate methods
    func shouldUpdateOutView(_ text: String, _ attr: [NSAttributedString.Key: Any]) {
        switch conversionType {
            case .audio:
                audioOutTextView.textStorage?.append(NSAttributedString(string: text, attributes: attr))
                scrollToBottom(audioOutTextView)
            case .video:
                videoOutTextView.textStorage?.append(NSAttributedString(string: text, attributes: attr))
                scrollToBottom(videoOutTextView)
            default:
            audioOutTextView.textStorage?.append(NSAttributedString(string: "audio and video not available", attributes: Constants.MessageAttribute.errorMessageAttributes))
            videoOutTextView.textStorage?.append(NSAttributedString(string: "audio and video not available", attributes: Constants.MessageAttribute.errorMessageAttributes))
        }
    }
    

    func showProgressBar(_ row: Int) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.15
            
        // Access data for each row from your data source
        guard let cell = filesTableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? CustomCellView else { return }
            cell.layer?.add(animation, forKey: "opacity")
            cell.progressView.isHidden = false
    }
    
    
    func conversionProgress(forRow row: Int, _ percent: Double) {
        guard let cell = filesTableView.view(
                atColumn: 0,
                row: row,
                makeIfNecessary: false
            ) as? CustomCellView else { return }
        cell.progressView.setProgress(percent, animated: true)
    }
    
    
    func resetAllProgressBar() {
        let numberOfRows = filesTableView.numberOfRows
        for row in 0..<numberOfRows {
            guard let cell = filesTableView.view(
                atColumn: 0,
                row: row,
                makeIfNecessary: false
            ) as? CustomCellView else { return }
            cell.progressView.doubleValue = 0.0
            let color = CIColor(red: 0.1, green: 0.9, blue: 0.1) // Green
            let filter = CIFilter(name: "CIFalseColor", parameters: [
                "inputColor0": color,
                "inputColor1": color
            ])!
            cell.progressView.contentFilters = [filter]
            cell.progressView.isHidden = true
        }
    }
    
    
    func progressBarError(_ row: Int) {
            guard let cell = filesTableView.view(
                atColumn: 0,
                row: row,
                makeIfNecessary: false
            ) as? CustomCellView else { return }
            let color = CIColor(red: 0.9, green: 0.1, blue: 0.1) // Red
            let filter = CIFilter(name: "CIFalseColor", parameters: [
                "inputColor0": color,
                "inputColor1": color
            ])!
        cell.progressView.contentFilters = [filter]
    }
    

    //MARK: NSTabView delegate methods
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        resetAllProgressBar()
    }
    
    
    //MARK: auto scroll on textView
    private func scrollToBottom(_ textView: NSTextView) {
        textView.scrollRangeToVisible(NSRange(location: textView.string.count, length: 0))
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
    
    
    
    //MARK: Format Descriptions functions
    func getFormatDescription(row: Int) -> String {
        var description: String = ""
        for (key, _) in files[row].formatDescription {
            if key == "videoDesc" {
                description += getVideoTrackDescription(videoFormatDesc: files[row].formatDescription["videoDesc"] as! CMFormatDescription,
                                                        rate: files[row].formatDescription["rate"] as! Float)
            } else if key == "audioDesc" {
                description += getAudioTrackDescription(audioFormatDesc: files[row].formatDescription["audioDesc"] as! CMFormatDescription)
            }
        }
        
        return description
    }
    
    
    
    func getVideoTrackDescription(videoFormatDesc: CMFormatDescription, rate: Float) -> String {
        var interlacedPregressive = ""
        var videoDescription: String = ""
        var movieColorPrimaries = ""
        var movieCodec = ""
        let mediaSubType = CMFormatDescriptionGetMediaSubType(videoFormatDesc).toString()
        
        //Getting video descriptors
        let movieDimensions =  CMVideoFormatDescriptionGetDimensions(videoFormatDesc)
        if let tempPrimaries = CMFormatDescriptionGetExtension(videoFormatDesc, extensionKey: kCMFormatDescriptionExtension_ColorPrimaries) {
            movieColorPrimaries = tempPrimaries as! String
            movieColorPrimaries = ", " + movieColorPrimaries
        }
        
        if let tempFields = CMFormatDescriptionGetExtension(videoFormatDesc, extensionKey: kCMFormatDescriptionExtension_FieldCount) {
            let movieFieldCount = tempFields
            if Int(truncating: movieFieldCount as! NSNumber) == 1 {
                interlacedPregressive = "p"
            } else if Int(truncating: movieFieldCount as! NSNumber) == 2 {
                interlacedPregressive = "i"
            }
        }
        
        if let tempDepth = CMFormatDescriptionGetExtension(videoFormatDesc, extensionKey: kCMFormatDescriptionExtension_Depth) {
            movieDepth = tempDepth
            
        }
        
        //Standarizing videoFrameRate (videoTrack.nominalFrameRate)
        var videoFrameRateString = ""
        switch Int(rate) {
        case 23:
            videoFrameRateString = String(format: "%2.2f", rate)
            break
        case 29:
            videoFrameRateString = String(format: "%2.2f", rate)
            break
        default:
            videoFrameRateString = String(format: "%2.0f", rate)
            break
        }
        
        //Standarizing video codec name
        if let formatName = CMFormatDescriptionGetExtension(videoFormatDesc, extensionKey: kCMFormatDescriptionExtension_FormatName)
        {
            switch mediaSubType.lowercased()
                {
                case "apch":
                    movieCodec = "Apple ProRes 422 (HQ)"
                    break
                case "apcn":
                    movieCodec = "Apple ProRes Standard"
                    break
                case "apcs":
                    movieCodec = "Apple ProRes LT"
                    break
                case "apco":
                    movieCodec = "Apple ProRes Proxy"
                    break
                case "ap4h":
                    movieCodec = "Apple ProRes 4444"
                    break
                case "ap4x":
                    movieCodec = "Apple ProRes 4444 XQ"
                    break
                case "avc1",
                    "h264",
                    "v264",
                    "avcb",
                    "x264":
                    movieCodec = "H.264"
                    break
                case "mpg4",
                    "mp4v":
                    movieCodec = "MPEG-4 Video"
                    break
                case "hev1":
                    movieCodec = "HEVC(hev1 tag not readable)"
                    break
                case "hvc1":
                    movieCodec = "HEVC"
                    break
                case "theo":                    
                    movieCodec = "Theora"
                    break
                default:
                    movieCodec = formatName as! String
                    break
                }
        }
        
        let depth = Int(truncating: movieDepth as? NSNumber ?? 0 )
        videoDescription = String(format: "Video: \(movieCodec), \(String(describing: movieDimensions.width))x\(String(describing: movieDimensions.height))\(interlacedPregressive), \(videoFrameRateString)fps\(movieColorPrimaries), Depth: \(depth)\n")
        
        return videoDescription
    }
    
    
    func getAudioTrackDescription(audioFormatDesc: CMFormatDescription) -> String {
        var audioDescription = ""
        var formatID: AudioFormatID!
        var formatIDDescription: String = ""
        var bitsPerChannel: UInt32 = 0
        var bitsPerChannelDescription: String = ""
        var channels: UInt32!
        var channelsDescription = ""
        var sampleRate: Float64 = 0.0
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc)
        
        formatID = asbd?.pointee.mFormatID 
        switch formatID {
        case kAudioFormatLinearPCM:
            formatIDDescription = "Linear PCM"
            break
        case kAudioFormatMPEG4AAC:
            formatIDDescription = "AAC"
            break
        case kAudioFormatMPEG4AAC_LD:
            formatIDDescription = "AAC-LD"
            break
        case kAudioFormatMPEG4AAC_HE:
            formatIDDescription = "AAC-HE"
            break
        case kAudioFormatMPEG4AAC_ELD:
            formatIDDescription = "AAC-ELD"
            break
        case kAudioFormatAC3:
            formatIDDescription = "AC3"
            break
        case kAudioFormatAppleIMA4:
            formatIDDescription = "Apple IMA4"
            break
        case kAudioFormatMPEGLayer1:
            formatIDDescription = "MPEG Layer 1"
            break
        case kAudioFormatMPEGLayer2:
            formatIDDescription = "MPEG Layer 2"
            break
        case  kAudioFormatMPEGLayer3:
            formatIDDescription = "MPEG Layer 3"
            break
        case kAudioFormatAppleLossless:
            formatIDDescription = "Apple Lossless"
            break
        case kAudioFormatAMR:
            formatIDDescription = "AMR"
            break
        case "vorb".toFourCharCode():
            formatIDDescription = "Vorbis"
            break
        case "opus".toFourCharCode():
            formatIDDescription = "Opus"
            break
        default:
            formatIDDescription = formatID.toString()
            break
        }
        
        if let tempBits = asbd?.pointee.mBitsPerChannel {bitsPerChannel = tempBits }
        if bitsPerChannel != 0 {
            bitsPerChannelDescription = "\(String(describing: bitsPerChannel))bits, "
        }
        if let tempSampleRate = asbd?.pointee.mSampleRate {
            sampleRate = tempSampleRate
            
        }
        //Channels
        if let tempChannels = asbd?.pointee.mChannelsPerFrame {
            channels = tempChannels
        }
        
        switch channels {
        case 1:
            channelsDescription = "Mono"
            
            break
        case 2:
            channelsDescription = "Stereo"
            
            break
        case 6:
            channelsDescription = "5.1"
            
            break
        default:
            channelsDescription  = String("\(channels)")
            break
        }
                
        audioDescription = String(format:"Audio: \(formatIDDescription), \(bitsPerChannelDescription)\(channelsDescription), %2.0fHz.\n", sampleRate)
        return audioDescription
    }

    
    func formatSecondsTime(_ seconds: Double) -> String {
        // Handle invalid or indefinite time
        guard !seconds.isNaN, seconds >= 0 else {
            return "00:00:00"
        }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    
}



extension FourCharCode {
    // Create a string representation of a FourCC.
    func toString() -> String {
        let bytes: [CChar] = [
            CChar((self >> 24) & 0xff),
            CChar((self >> 16) & 0xff),
            CChar((self >> 8) & 0xff),
            CChar(self & 0xff),
            0
        ]
        let result = String(cString: bytes)
        let characterSet = CharacterSet.whitespaces
        return result.trimmingCharacters(in: characterSet)
    }
    
    
}


extension String {
    func toFourCharCode() -> FourCharCode? {
        guard self.count == 4 else {
            return nil
        }
        
        var result: FourCharCode = 0
        for char in self.utf8 {
            result = (result << 8) | FourCharCode(char)
        }
        return result
    }
}

