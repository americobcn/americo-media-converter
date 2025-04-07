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
    @IBOutlet weak var chooseFolder: NSButton!
    
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
    
    
    let regularMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.lightGray
    ]
    
    let errorMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.red
    ]
    
    let succesMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.green
    ]
    
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
        audioOutTextView.backgroundColor = .black
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
        filesTableView.allowsMultipleSelection = true
        filesTableView.rowHeight = 60
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
        if files.count < 1 {
            return
        }
        
        var destinationFolder: String?
        if chooseFolder.state == .on {
            destinationFolder = chooseFolderDestination()
            if destinationFolder == nil {
                return
            }
            print("Choosing folder: \(String(describing: destinationFolder))")
        } else {
            destinationFolder = nil
        }
                
        var arguments: String = ""
    
        switch audioTypeButton.title {
        case "WAV":
            arguments = String(format: "-v -f BW64 -d LEI%@@%@ -o", audioBitsButton.title ,audioFrequencyButton.title) // AFCONVERT
        case "AAC":
            // arguments = String(format: "-codec:a %@ -b:a %@k",  audioTypeButton.title.lowercased(), audioBitsButton.title.lowercased()) //FFMPEG
            arguments = String(format: "-v -f m4af -d aac -s 0 -b %@000 -o", audioBitsButton.title)  // AFCONVERT
            break
        case "MP3":
            arguments = String(format: "-b %@ -o", audioBitsButton.title) // LAME
            break
        default:
            audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: "Something went wrong" , attributes: errorMessageAttributes))
            return
        }
        
        audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        for file in files {
            ac.convertAudio(file: file.mfURL, codec: audioTypeButton.title, args: arguments, textView: audioOutTextView, destinationFolder: destinationFolder) {
                success, message in
                if success {
                    print(message)
                } else {
                    print(message)
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
            audioBitsButton.addItems(withTitles: ["24", "16", "32"])
            break
        case "AAC":
            audioOutTextView.textStorage?.append(NSAttributedString(string: "Changed to AAC\n"))
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["320", "256", "192", "128"])
            break
        case "MP3":
            audioOutTextView.textStorage?.append(NSAttributedString(string: "Changed to MP3\n"))
            audioBitsLabel.stringValue = "Bit Rate"
            audioBitsButton.removeAllItems()
            audioBitsButton.addItems(withTitles: ["320", "256", "192", "128"])
            break
        default:
            audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: "Something went wrong" , attributes: errorMessageAttributes))
            return
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
    
    
    // MARK: AudioConverterDelegate methods
    func shouldUpdateAudioOutView(_ text: String) {
        // let attr = error ?  errorMessageAttributes : succesMessageAttributes
        audioOutTextView.textStorage?.append(NSAttributedString(string: text, attributes: regularMessageAttributes))
        scrollToBottom()
    }
    
    private func scrollToBottom() {
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
        
        videoDescription = String(format: "Video: \(movieCodec), \(String(describing: movieDimensions.width))x\(String(describing: movieDimensions.height))\(interlacedPregressive), \(videoFrameRateString)fps\(movieColorPrimaries), Depth: %ibits \n", Int(truncating: movieDepth as! NSNumber ))
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
