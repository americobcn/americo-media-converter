//
//  MVC.swift
//  MyApp
//
//  Created by Américo Cot Toloza on 21/3/25.
//

import Cocoa
import AVFoundation
import AVKit

class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NavigationBarDelegate, AudioConverterDelegate {
    // MARK: Views Outlets
    @IBOutlet weak var filesTableView: NSTableView!
    // @IBOutlet weak var navBarView: NSView!
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var audioOutTextView: NSTextView!
    @IBOutlet weak var audioOutScrollView: NSScrollView!
    
    // MARK: Audio Outlets
    @IBOutlet weak var audioTypeLabel: NSTextField!
    @IBOutlet weak var audioBitsLabel: NSTextField!
    @IBOutlet weak var audioFrequencyLabel: NSTextField!
    @IBOutlet weak var audioTypeButton:NSPopUpButton!
    @IBOutlet weak var audioBitsButton:NSPopUpButton!
    @IBOutlet weak var audioFrequencyButton:NSPopUpButton!
    
    var documentView: NSView!
    
    private var contentView: NSView!
    var navBar: NavigationBarView!
        
    // MARK: Media related variables
    struct mediaFile {
        var mfURL: URL
        var formatsDescriptions: [String: Any] = [:] //CMFormatDescription
    }
        
    var files: [mediaFile] = []
    let mc = MediaController()
    var movieDepth: CFPropertyList?
        
    let vc = VideoConverter()
    var ac: AudioConverter!
    
    
    // MARK: Initializers
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        ac = AudioConverter(delegate: self)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupConverterView()
        setupPlayerView()
        setupOutputView()
    }
    
    
    func setupPlayerView() {
        playerView.wantsLayer = true
        playerView.showsFrameSteppingButtons = true
        playerView.player = AVPlayer()
    }
    
    
    func setupOutputView() {
        // documentView = audioOutScrollView.documentView
        // Configure ScrollView
        // audioOutScrollView.wantsLayer = true
        // audioOutScrollView.translatesAutoresizingMaskIntoConstraints = false
        // audioOutScrollView.hasVerticalScroller = true
        // audioOutScrollView.hasHorizontalScroller = false
        // audioOutScrollView.autohidesScrollers = true
        
        // Configure TextView
        // audioOutTextView.isEditable = false
        // audioOutTextView.isSelectable = true
        // audioOutTextView.isVerticallyResizable = true
        // audioOutTextView.isHorizontallyResizable = false
        // audioOutTextView.textContainer?.widthTracksTextView = true
        // audioOutTextView.textContainer?.heightTracksTextView = false
        audioOutTextView.backgroundColor = .lightGray
        // audioOutTextView.textColor = .white
        // audioOutTextView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        
        // Enable text wrapping
        // audioOutTextView.textContainer?.lineBreakMode = .byWordWrapping
        
        // Set ScrollView's document view
        // audioOutScrollView.documentView = audioOutTextView
        
    }
    
    
    func setupConverterView() {
        audioTypeButton.removeAllItems()
        audioTypeButton.addItems(withTitles: ["MP3" , "AAC", "WAV"])
        audioBitsButton.removeAllItems()
        audioBitsButton.addItems(withTitles: ["320", "256", "128"])
        audioFrequencyButton.removeAllItems()
        audioFrequencyButton.addItems(withTitles: ["48000", "44100"])
    }
    
    
    func setupTableView() {
        filesTableView.delegate = self
        filesTableView.dataSource = self
        filesTableView.registerForDraggedTypes([.fileURL])
    }
   
    
    /*
    func setupNavBar() {
        contentView = NSView(frame: NSRect(x: 750, y: 20, width: 800, height: 550))
        view.addSubview(contentView)
        
        let homeView = NSView(frame: contentView.bounds)
        homeView.wantsLayer = true
        homeView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        //
        let settingsView = NSView(frame: contentView.bounds)
        settingsView.wantsLayer = true
        settingsView.layer?.backgroundColor = NSColor.systemGreen.cgColor
        //
        let profileView = NSView(frame: contentView.bounds)
        profileView.wantsLayer = true
        profileView.layer?.backgroundColor = NSColor.systemRed.cgColor
        
        navBar = NavigationBarView(frame: NSRect(x: 0, y: 0, width: navBarView.bounds.width  , height: navBarView.bounds.height),
                                   views: [])
        navBar.delegate = self
        navBarView.addSubview(navBar)
        
    }
    */
    
    
    //MARK: IBAction Methods
    @IBAction func convertAudio(_ sender: NSButton) {
        // audioOutTextView.textStorage?.setAttributedString(NSAttributedString())
        // audioOutTextView.textStorage?.append(NSAttributedString(string: "Converting"))
        var arguments: String = ""
        var bitFepth = ""
        
        if audioTypeButton.title == "WAV" {
            switch audioBitsButton.title {
            case "24":
                bitFepth = "pcm_s24le"
            case "32":
                bitFepth = "pcm_s32le"
            default:
                bitFepth = "pcm_s16le"
            }
        }
        
        switch audioTypeButton.title {
        case "AAC":
            arguments = String(format: "-codec:a %@ -b:a %@k",  audioTypeButton.title.lowercased(), audioBitsButton.title.lowercased())
            break
        case "WAV":
            arguments = String(format: "-c:a %@ -ar %@",  bitFepth,  audioFrequencyButton.title)
            break
        case "MP3":
            arguments = String(format: "-b %@ -o", audioBitsButton.title)
            break
        default:
            break
            // audioOutTextView.textStorage?.append(NSAttributedString(string: "Something went wrong"))
        }
        
        audioOutTextView.textStorage?.append(NSAttributedString(string: "\(bitFepth) \(arguments)"))
        for file in files {
            ac.convertAudio(file: file.mfURL.path, codec: audioTypeButton.title, args: arguments ) {
                success, error in
                if success {
                    DispatchQueue.main.async {
//                        print("Conversion Succesfull")
                        self.audioOutTextView.textStorage?.append(NSAttributedString(string: "Conversion successful"))
                    }
                } else {
//                    print("Error: \(error ?? "Unknown error")")
                    self.audioOutTextView.textStorage?.append(NSAttributedString(string: "Error: \(error ?? "Unknown error")"))
                }
            }
        }
    }
    

    @IBAction func audioTypeChanged(_ sender: NSPopUpButton) {
        switch sender.title {
        case "WAV":
            audioOutTextView.textStorage?.append(NSAttributedString(string: "Changed to WAV\n"))
            audioBitsLabel.stringValue = "Bit Depth"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["24", "16"])
        case "AAC":
            audioOutTextView.textStorage?.append(NSAttributedString(string: "Changed to AAC\n"))
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["320", "256", "192", "128"])
        case "MP3":
            audioOutTextView.textStorage?.append(NSAttributedString(string: "Changed to MP3\n"))
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["320", "256", "192", "128"])
        default:
            break
        }
    }
    
    
    // MARK: NavigationBarDelegate methods
    func didSelectView(_ view: NSView) {
        print("Button tapped: \(view)")
        // contentView.subviews.forEach { $0.removeFromSuperview() }
        // contentView.addSubview(view)
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
            if files[row].formatsDescriptions.keys.contains("videoDesc") {
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
            // print("MOVING")
            // print("SELECTED ROWS: \(self.filesTableView.selectedRow)")
            guard let sourceRow = tableView.selectedRowIndexes.first else {
                //print("RETURNING 1")
                return false
            }
            
            guard sourceRow != row else {
                //print("RETURNING 2")
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
                            formatsDescriptions: mfInfo.1
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
        let selectedRow = filesTableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        files.remove(at: selectedRow) // Remove from data source
        filesTableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .effectFade)
        playerView.player?.replaceCurrentItem(with: nil)
    }
    
    
    // MARK: AudioConverterDelegate methods
    func shouldUpdateAudioOutView(_ converter: AudioConverter, _ text: String) {
        audioOutTextView.textStorage?.append(NSAttributedString(string: text))
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        // let scrollView = audioOutTextView.enclosingScrollView!
        // guard let documentView = audioOutScrollView.documentView else { return }
        // let newScrollOrigin = NSPoint(x: 0, y: documentView.bounds.height - audioOutScrollView.contentView.bounds.height)
        // audioOutScrollView.contentView.setBoundsOrigin(newScrollOrigin)
        audioOutTextView.scrollRangeToVisible(NSRange(location: audioOutTextView.string.count, length: 0))
    }
    
    
    
    // MARK: Format Descriptions functions
    func getFormatDescription(row: Int) -> String {
        var description: String = ""
        for (key, _) in files[row].formatsDescriptions {
            if key == "videoDesc" {
                description += getVideoTrackDescription(videoFormatDesc: files[row].formatsDescriptions["videoDesc"] as! CMFormatDescription,
                                                        rate: files[row].formatsDescriptions["rate"] as! Float)
            }
            
            if key == "audioDesc" {
                description += getAudioTrackDescription(audioFormatDesc: files[row].formatsDescriptions["audioDesc"] as! CMFormatDescription)
            }
        }
        
        return description
    }
    
    
    func getVideoTrackDescription(videoFormatDesc: CMFormatDescription, rate: Float) -> String {
        var interlacedPregressive = ""
        var videoDescription: String = ""
        var movieColorPrimaries = ""
        var movieCodec = ""
        
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
            switch formatName as! String
            {
            case "'apch'":
                movieCodec = "Apple ProRes 422 (HQ)"
                break
            case "'avc1'",
                "'x264'":
                movieCodec = "H.264"
                break
            case "'mpg4'",
                "'mp4v'":
                movieCodec = "MPEG-4 Video"
                break
            case "'hev1'":
                movieCodec = "HEVC(hev1 tag not readable)"
                break
            case "'hvc1'":
                movieCodec = "HEVC"
                break
            default:
                movieCodec = formatName as! String
                break
            }
        }
        
        videoDescription = String(format: "Video: \(movieCodec), \(String(describing: movieDimensions.width))x\(String(describing: movieDimensions.height))\(interlacedPregressive) \(videoFrameRateString)fps\(movieColorPrimaries), %ibits\n",Int(truncating: movieDepth as! NSNumber ))
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
        
        formatID = asbd?.pointee.mFormatID //.toString() as! String
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
        default:
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
