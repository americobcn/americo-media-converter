//
//  MVC.swift
//  MyApp
//
//  Created by Américo Cot Toloza on 21/3/25.
//

import Cocoa
import AVFoundation
import AVKit

class MVC: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NavigationBarDelegate {
    // MARK: Views relate variables
    @IBOutlet weak var filesTableView: NSTableView!
    @IBOutlet weak var navBarView: NSView!
    @IBOutlet weak var playerView: AVPlayerView!
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
    
    
    // MARK: Initializers
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    //     setupNavBar()
        
    }
    
    
    func setupTableView() {
        filesTableView.delegate = self
        filesTableView.dataSource = self
        filesTableView.registerForDraggedTypes([.fileURL])
    }
    
    
    func setupNavBar() {
        contentView = NSView(frame: NSRect(x: 750, y: 20, width: 800, height: 550))
        view.addSubview(contentView)
        
        let homeView = NSView(frame: contentView.bounds)
        homeView.wantsLayer = true
        homeView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        
        let settingsView = NSView(frame: contentView.bounds)
        settingsView.wantsLayer = true
        settingsView.layer?.backgroundColor = NSColor.systemGreen.cgColor
        
        let profileView = NSView(frame: contentView.bounds)
        profileView.wantsLayer = true
        profileView.layer?.backgroundColor = NSColor.systemRed.cgColor
        
        navBar = NavigationBarView(frame: NSRect(x: 0, y: 0, width: navBarView.bounds.width  , height: navBarView.bounds.height),
                                   views: [homeView, settingsView, profileView])
        navBar.delegate = self
        navBarView.addSubview(navBar)

    }
    
    
    // MARK: NavigationBarDelegate methods
    func didSelectView(_ view: NSView) {
        print("Button tapped: \(view)")
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.addSubview(view)
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
            playerView.player = AVPlayer()
            playerView.player?.replaceCurrentItem(with: item)
            
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
        if dropOperation == .above {
            return .move
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
