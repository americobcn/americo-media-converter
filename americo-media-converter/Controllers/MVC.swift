import Cocoa
import AVFoundation
import AVKit

class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource , ConverterDelegate { // NavigationBarDelegate
    
    // MARK: Views Outlets
    @IBOutlet weak var filesTableView: NSTableView!
    @IBOutlet weak var playerView: AVPlayerView!
    
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
    @IBOutlet weak var videoPadButton: NSButton!
    
        
    // MARK: Media related variables
    struct mediaFile {
        var mfURL: URL
        var formatDescription: [String: Any] = [:] //CMFormatDescription
    }
    
    var files: [mediaFile] = []
    let mc = MediaController()
    var movieDepth: CFPropertyList?
    
    var newAudioExtension: String = ""
    var newVideoExtension: String = ""
    var cv: Converter!
    var conversionType: Constants.ConversionType!
    let prefs = PreferencesManager.shared
    
    // MARK: PopUp Button titles
    
    enum VideoResolution: CaseIterable {
        case sd480, sd576
            case hd720, hd1080
            case cinema2K
            case uhd4K, cinema4K, cinema5K
            case uhd8K
        
        var size: (width: Int, height: Int) {
            switch self {
            case .sd480: return (720, 480)
            case .sd576: return (720, 576)
            case .hd720: return (1280, 720)
            case .hd1080: return (1920, 1080)
            case .cinema2K: return (2048, 1080)
            case .uhd4K: return (3840, 2160)
            case .cinema4K: return (4096, 2160)
            case .cinema5K: return (5120,2700)
            case .uhd8K: return (7680, 4320)
            }
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
    
    enum VideoCodecs: String, CaseIterable {
        case ProRes = "ProRes"
        case DNxHD = "DNxHD"
        case H264 = "H264"
        
        var codec: String {
            switch self {
            case .ProRes: return "prores_ks"
            case .DNxHD: return "dnxhd"
            case .H264: return "libx264"
            }
        }
    }

    
    enum VideoProfiles: String, CaseIterable {
        case ProRes, DNxHD, H264
    
        var profiles: [(title: String, profile: String)] {
            switch self {
            case .ProRes: return [("HQ", "3"), ("LT", "1"), ("Standard", "2"), ("4444", "4")]
            case .DNxHD: return [("HQ", "dnxhr_hq"), ("Standard", "dnxhr_sq"), ("HQ 10 bits", "dnxhr_hqx"), ("HQ 4:4:4", "dnxhr_444")]
            case .H264: return [("Main", "main"), ("High", "high"), ("Baseline", "baseline")]
            }
        }
    }
    
    
    // MARK: Dictionaries
    let videoCodecsDict: [String: String] = [
        "ProRes": "prores_ks",
        "DNxHD": "dnxhd",
        "H264": "libx264"
    ]
    

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
        // Audio Buttons setup
        audioTypeButton.removeAllItems()
        audioTypeButton.addItems(withTitles: ["MP3" , "AAC", "WAV"])
        audioBitsButton.removeAllItems()
        audioBitsButton.addItems(withTitles: ["320", "256", "192", "128"])
        audioFrequencyButton.removeAllItems()
        audioFrequencyButton.addItems(withTitles: ["48000", "44100"])
        
        // Video Buttons setup
        videoCodecButton.removeAllItems()
        videoCodecButton.addItems(withTitles: VideoCodecs.allCases.map { $0.rawValue })
//        videoCodecButton.addItems(withTitles: Array(videoCodecsDict.keys))
        videoCodecButton.selectItem(withTitle: "ProRes")
        videoProfileButton.removeAllItems()
        videoProfileButton.addItems(withTitles: VideoProfiles.ProRes.profiles.map { $0.title})
        videoProfileButton.selectItem(withTitle: "HQ")
        videoResolutionButton.removeAllItems()
        videoResolutionButton.addItems(withTitles: VideoResolution.allCases.map { $0.resolutionString })
        videoResolutionButton.selectItem(withTitle: "1920x1080")
        videoContainerButton.removeAllItems()
        videoContainerButton.addItems(withTitles: VideoContainers.ProRes.containers)

        videoContainerButton.selectItem(withTitle: "MOV")
        videoPadButton.state = .off
    }
    
    
    func setupTableView() {
        filesTableView.delegate = self
        filesTableView.dataSource = self
        filesTableView.registerForDraggedTypes([.fileURL])
        filesTableView.allowsMultipleSelection = true
        filesTableView.rowHeight = 60
    }
    
    
    //MARK: IBAction Methods
    @IBAction func convertAudio(_ sender: NSButton) {
        audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        if files.count < 1 {
            return
        }
        
        conversionType = .audio
        
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
        
        var arguments: String = ""
        
        switch audioTypeButton.title {
        case "WAV":
            if audioBitsButton.title == "24" {
                arguments = String(format: "-y -sample_fmt s32 -c:a pcm_s%@le -ar %@", audioBitsButton.title, audioFrequencyButton.title ) // FFMPEG
            } else {
                arguments = String(format: "-y -sample_fmt s%@ -c:a pcm_s%@le -ar %@", audioBitsButton.title, audioBitsButton.title, audioFrequencyButton.title )
            }
            break
        case "AAC":
            let bufferSize = Int(audioBitsButton.title)! * 2
            arguments = String(format: "-y -vn -c:a aac -b:a %@k -maxrate %@k -bufsize %@k -ar %@", audioBitsButton.title, audioBitsButton.title, String(bufferSize), audioFrequencyButton.title) //FFMPEG
            // arguments = String(format: "-v -f m4af -d aac -s 0 -b %@000 -o", audioBitsButton.title)  // AFCONVERT
            break
        case "MP3":
            //arguments = String(format: "-b %@ -o", audioBitsButton.title) // LAME
            arguments = String(format: "-y -codec:a libmp3lame -b:a %@k -ar %@", audioBitsButton.title, audioFrequencyButton.title) //FFMPEG
            break
        default:
            audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: "Something went wrong" , attributes: Constants.MessageAttribute.errorMessageAttributes))
            return
        }
        
        switch audioTypeButton.title {
            case "MP3":
                newAudioExtension = "mp3"
                break
            case "AAC":
                newAudioExtension = "m4a"
                break
            default:
                newAudioExtension = "wav"
                break
        }
        
        audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        for file in files {
            let outPath = composeFileURL(of: file.mfURL, to: newAudioExtension, destinationFolder)
            // arguments.append(outPath)
            cv.convert(fileURL: file.mfURL, args: arguments, outPath: outPath) {
                success, message, exitCode in
                if success {
                    print(exitCode)
                    print(message ?? "Success")
                    self.videoOutTextView.textStorage?.append(NSAttributedString(string: "Succesfully converted \(file.mfURL)\n", attributes: Constants.MessageAttribute.succesMessageAttributes))
                } else {
                    print(exitCode)
                    print(message ?? "Error")
                    self.videoOutTextView.textStorage?.append(NSAttributedString(string: "Failed to convert \(file.mfURL)\n", attributes: Constants.MessageAttribute.errorMessageAttributes))
                }
            }
        }
    }
    
    
    
    @IBAction func convertVideo(_ sender: NSButton) {
        videoOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        if files.count < 1 {
            return
        }
        
        conversionType = .video
        
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
            
        var arguments: String = ""
        var resolution: String = ""
        var videoProfile: VideoProfiles?
        var profile: String = ""
        if let vp = VideoProfiles.allCases.first(where: { $0.rawValue == videoCodecButton.title }) {
            videoProfile = vp
            print("VIDEOPROFILE: \(videoProfile!)")
        }
        
        if let prof = videoProfile?.profiles.first(where: { $0.title == videoProfileButton.title })?.profile {
            profile = prof
            print("PROFILE: \(profile)")
        }
                
        if let res = VideoResolution.allCases.first(where: { $0.resolutionString == videoResolutionButton.title })?.ffmpegString {
            resolution = res
            print("RESOLUTION: \(resolution)")
        }
        
        switch videoCodecButton.title {
        case "ProRes":
            if videoPadButton.state == .on {
                arguments = "-y -c:v prores_ks -profile:v \(profile) -qscale:v 9 -vendor apl0 -pix_fmt yuv422p10le -vf scale=\(resolution):force_original_aspect_ratio=decrease,pad=\(resolution):(ow-iw)/2:(oh-ih)/2"
            } else {
                arguments = "-y -c:v prores_ks -profile:v \(profile) -qscale:v 9 -vendor apl0 -pix_fmt yuv422p10le -vf scale=\(resolution):force_original_aspect_ratio=decrease"
            }
            break
            
        case "H264":
            if videoPadButton.state == .on {
                arguments = "-y -c:v libx264 -profile:v high422 -preset slow -crf 18 -vf format=yuv420p -vf scale=\(resolution):force_original_aspect_ratio=decrease,pad=\(resolution):(ow-iw)/2:(oh-ih)/2 -c:a copy"
            } else {
                arguments = "-y -c:v libx264 -profile:v high422 -preset slow -crf 18 -vf format=yuv420p -vf scale=\(resolution):force_original_aspect_ratio=decrease -c:a copy"
            }
            break
            
        case "DNxHD":
            var pix_fmt: String
            switch profile {
            case "dnxhr_hqx":
                pix_fmt = "yuv422p10le"
                break
            case "dnxhr_444":
                pix_fmt = "yuv444p10le"
                break
            default:
                pix_fmt = "yuv422p"
            }
                                
            if videoPadButton.state == .on {
                arguments = "-y -c:v dnxhd -profile:v \(profile) -pix_fmt yuv422p -vf scale=\(resolution):force_original_aspect_ratio=decrease,pad=\(resolution):(ow-iw)/2:(oh-ih)/2 -c:a pcm_s24le"
            } else {
                arguments = "-y -c:v dnxhd -profile:v \(profile) -pix_fmt \(pix_fmt) -vf scale=\(resolution) -c:a pcm_s24le"
            }
            break
            
        default:
            return
        }
        
        newVideoExtension = videoContainerButton.title.lowercased() // Default extension
        for file in files {
            videoOutTextView.textStorage?.append(NSAttributedString(string: "Converting \(file.mfURL)\n", attributes: Constants.MessageAttribute.regularMessageAttributes))
            let outPath = composeFileURL(of: file.mfURL, to: newVideoExtension, destinationFolder)
            cv.convert(fileURL: file.mfURL, args: arguments, outPath: outPath) {
                success, message, exitCode in
                if success {
                    print(message ?? "Success")
                    self.videoOutTextView.textStorage?.append(NSAttributedString(string: "Succesfully converted \(file.mfURL)\n", attributes: Constants.MessageAttribute.succesMessageAttributes))
                } else {
                    print(message ?? "Error")
                    self.videoOutTextView.textStorage?.append(NSAttributedString(string: "Failed to convert \(file.mfURL)\n", attributes: Constants.MessageAttribute.errorMessageAttributes))
                }
            }
        }
    }
    
    
    
    @IBAction func audioTypeChanged(_ sender: NSPopUpButton) {
        switch sender.title {
        case "WAV":
            audioBitsLabel.stringValue = "Bit Depth"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["24", "16", "32"])
            audioFrequencyButton.removeAllItems()
            audioFrequencyButton.addItems(withTitles: ["96000","48000","44100"])
            audioFrequencyButton.selectItem(at: 1)
            break
        case "AAC":
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["320", "256", "192", "128"])
            audioFrequencyButton.removeAllItems()
            audioFrequencyButton.addItems(withTitles: ["48000","44100"])
            break
        case "MP3":            
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["320", "256", "192", "128"])
            audioFrequencyButton.removeAllItems()
            audioFrequencyButton.addItems(withTitles: ["48000","44100"])
            break
        default:
            audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: "Something went wrong" , attributes: Constants.MessageAttribute.errorMessageAttributes))
            return
        }
    }
    
    
    @IBAction func videoCodecChanged(_ sender: NSPopUpButton) {
        switch sender.title {
        case "ProRes":
            videoProfileButton.removeAllItems()
            videoProfileButton.addItems(withTitles: VideoProfiles.ProRes.profiles.map { $0.title})
            videoProfileButton.selectItem(withTitle: "HQ")
            videoContainerButton.removeAllItems()
            videoContainerButton.addItems(withTitles: VideoContainers.ProRes.containers)
            break
        case "H264":
            videoProfileButton.removeAllItems()
            videoProfileButton.addItems(withTitles: VideoProfiles.H264.profiles.map { $0.title})
            videoProfileButton.selectItem(withTitle: "Main")
            videoContainerButton.removeAllItems()
            videoContainerButton.addItems(withTitles: VideoContainers.H264.containers)
            break
        case "DNxHD":
            videoProfileButton.removeAllItems()
            videoProfileButton.addItems(withTitles: VideoProfiles.DNxHD.profiles.map { $0.title})
            videoProfileButton.selectItem(withTitle: "HQ")
            videoContainerButton.removeAllItems()
            videoContainerButton.addItems(withTitles: VideoContainers.DNxHD.containers)
            break
        default:
            break
        }
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
                print("The directory exists and we have write permissions.")
                return true
            }
        } catch {
            Constants.dropAlert(message: "Destination path in preferences is not available or writable.",
                                informative: "Choose a valid folder.")
            print("An error occurred, choosing destination folder.")
        }
        return false
    }
        
    
    
    // MARK:  TableView Datasource Methods
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        return files.count
    }
    
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let colIdentifier = tableColumn?.identifier else { return nil }
        switch colIdentifier {
        case NSUserInterfaceItemIdentifier(rawValue: "fileColumn"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "fileCell"), owner: self ) as? CustomCellView
            else { return nil }
            viewCell.fileNameLabel.stringValue = files[row].mfURL.lastPathComponent
            viewCell.fileInfoLabel.stringValue = getFormatDescription(row: row)
            if files[row].formatDescription.keys.contains("videoDesc") {
                viewCell.cellImageView.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)
            } else {
                viewCell.cellImageView.image = NSImage(systemSymbolName: "hifispeaker", accessibilityDescription: nil)
            }
            
            return viewCell
        case NSUserInterfaceItemIdentifier(rawValue: "urlColumn"):
            guard let viewCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "urlCell"), owner: self ) as? NSTableCellView
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
    
    
    
    func tableView(_ tableView: NSTableView,
                   pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
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
            
            guard sourceRow != row else {
                return false
            } // Prevent dropping onto the same row
            
            let draggedItem = files[sourceRow]
            files.remove(at: sourceRow)
            
            // Adjust the destination index when dragging downwards
            let adjustedIndex = row > sourceRow ? row - 1 : row
            files.insert(draggedItem, at: adjustedIndex)
            tableView.moveRow(at: sourceRow, to: adjustedIndex)
            return true
            
        // Dragged files from finder
        } else if info.draggingPasteboard.types?.contains(.fileURL) == true {
            // print("DROPPED")
            guard let pasteboardObjects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil),
                  pasteboardObjects.count > 0 else {
                return false
            }
            pasteboardObjects.forEach { (object) in
                if let url = object as? NSURL {
                    let mfInfo = mc.isAVMediaType(url: url as URL)
                    if mfInfo.0 == true {
                        let mfFile: mediaFile! = mediaFile(
                            mfURL: URL(fileURLWithPath: url.path!),
                            formatDescription: mfInfo.1
                        )
                        files.append(mfFile)
                    }
                }
            }
            tableView.reloadData()
            return true
        }
        
        return false
    }
    
    
    
    // MARK: Keyboard event handlers
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51:
            deleteSelectedRow()
            break
        case 49:
            playPause()
            break
        default:
            super.keyDown(with: event)
        }
    }
    
    
    
    private func playPause() {
        if playerView.player?.rate == 0.0  {
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
            } // else {
//                if let formatDesc = files[row].formatDescription["format"] as? NSDictionary {
//                    if let long_name = formatDesc["format_long_name"] {
//                        description = long_name as! String
//                    }
//                }
//            }
        }
        
        return description
    }
    
    
    
    func getVideoTrackDescription(videoFormatDesc: CMFormatDescription, rate: Float) -> String {
        var interlacedPregressive = ""
        var videoDescription: String = ""
        var movieColorPrimaries = ""
        var movieCodec = ""
        let mediaSubType = CMFormatDescriptionGetMediaSubType(videoFormatDesc).toString()
        // print("MEDIA SUB TYPE: \(mediaSubType)")
        // print("MEDIA SUB TYPE: \(videoFormatDesc.mediaSubType)")
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
        
        videoDescription = String(format: "Video: \(movieCodec), \(String(describing: movieDimensions.width))x\(String(describing: movieDimensions.height))\(interlacedPregressive), \(videoFrameRateString)fps\(movieColorPrimaries), Depth: %ibits \n", Int(truncating: movieDepth as? NSNumber ?? 0 ))
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
        
        audioDescription = String(format:"Audio: \(formatIDDescription), \(bitsPerChannelDescription)\(channelsDescription), %2.0fHz\n", sampleRate)
        return audioDescription
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

