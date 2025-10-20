//
//  MediaController.swift
//  MyApp
//
//  Created by Américo Cot on 23/3/25.
//

import Foundation
import AVFoundation


class MediaController {
    var urlAsset: AVURLAsset!
    var videoFormatDesc: CMFormatDescription!
    var audioFormatDesc: CMFormatDescription!
    var ffprobeURL: URL!
    var format: [String:Any] = [:]
    
    init() {
        self.ffprobeURL = nil
        if !checkFFprobe() {
            _ = Constants.dropAlert(message: "ffprobe is missing", informative: "Some info will not be available until you install ffprobe binary in Resources folder of the app.\nIf ffprobe is located in /usr/local/bin/ffprobe, copy the binary in the Resources folder of the app.")
        }
    }
    
    
    
    func isAVMediaType(url: URL) -> (isPlayable: Bool, formats: [String: Any]) {
        let extensions: Set<String> = ["ogg", "weba", "webm", "eac3", "adx", "aea", "amr", "g722"]
        if extensions.contains(url.pathExtension.lowercased()) {
            let process = Process()
            process.executableURL = ffprobeURL
            let arguments = "-v quiet -show_format -show_streams -print_format json \(url.path)"  // ffprobe -v quiet -show_format -show_streams -print_format json input.mp4
            process.arguments = arguments.components(separatedBy: .whitespaces)
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
                    
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        print(output)
                    }
                } catch {
                    print("Failed to run process: $$error)")
                }
        
            return (isPlayable: true, formats: [:])
        }
        
        let urlAsset = AVURLAsset(url: url)
        if urlAsset.isPlayable {
            format = getMetadata(asset: urlAsset)
            // print("FORMAT: \(format)\n")
            return (isPlayable: true, formats: format)
        }
        
        return (isPlayable: false, formats: format)
    }
    
    
    
    func getMetadata(asset: AVURLAsset ) -> [String: Any] {
        var videoFormatDesc: CMVideoFormatDescription?
        var audioFormatDesc: CMAudioFormatDescription?
        var timeFromatDesc: CMTimeCodeFormatDescription?
        
        var formats: [String:Any] = [:]
        // print("ASSET DESCRIPTION: \(mediaAssetDescription(asset: asset, mediaType: kCMMediaType_Video))")
        for track in asset.tracks {
            // print("DESCRIPTORS: \(track.formatDescriptions)")
            switch track.mediaType {
            case .video:
                videoFormatDesc = ((track.formatDescriptions[0] ) as! CMVideoFormatDescription)
                formats["videoDesc"] = videoFormatDesc
                formats["rate"] = track.nominalFrameRate
                formats["icon"] = "video"
                break
            case .audio:
                audioFormatDesc = ((track.formatDescriptions[0] ) as! CMAudioFormatDescription)
                formats["audioDesc"] = audioFormatDesc
                formats["icon"] = "hifispeaker"
                break
            case .timecode:
                timeFromatDesc = ((track.formatDescriptions[0]) as! CMTimeCodeFormatDescription)
                formats["tcDesc"] = timeFromatDesc
            default:
                break
            }
        }
        // print("TC Frame Rate: \(timeFromatDesc?.frameQuanta ?? 0)")
        return  formats
    }
    
    
    func mediaAssetDescription(asset: AVURLAsset, mediaType: CMMediaType) -> [Any] {
        let formatDescriptions = asset.tracks.flatMap { $0.formatDescriptions }
        // let mediaSubtypes = formatDescriptions
        //     .filter { CMFormatDescriptionGetMediaType($0 as! CMFormatDescription) == mediaType }
        //     .map { CMFormatDescriptionGetMediaSubType($0 as! CMFormatDescription).toString() }
        return formatDescriptions.filter { CMFormatDescriptionGetMediaType($0 as! CMFormatDescription) == mediaType }
    }
    
    
    func checkFFprobe() -> Bool {
        self.ffprobeURL = Bundle.main.url(forResource: "ffprobe", withExtension: nil)
        if  self.ffprobeURL != nil {
            return true
        } else {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            task.arguments = ["ffprobe"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if data.isEmpty {
                return false
            }
            
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) {
                self.ffprobeURL = URL(fileURLWithPath: path)
                return true
            } else {
                return false
            }
        }
    }

    
}
