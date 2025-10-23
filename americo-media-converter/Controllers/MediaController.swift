//
//  MediaController.swift
//  MyApp
//
//  Created by Américo Cot on 23/3/25.
//

import Foundation
import CoreMedia
import AVFoundation


class MediaController {
    
    var urlAsset: AVURLAsset!
    var videoFormatDesc: CMFormatDescription!
    var audioFormatDesc: CMFormatDescription!
    var ffprobeURL: URL!
    var ffmpegURL: URL!
    var format: [String:Any] = [:]
    
    // MARK: - FFprobe JSON Models

    struct FFprobeOutput: Codable {
        let streams: [FFprobeStream]
        let format: FFprobeFormat
    }

    struct FFprobeStream: Codable {
        let index: Int
        let codecType: String
        let codecName: String
        let codecLongName: String?
        let profile: String?
        let codecTagString: String
        let codecTag: String
        let width: Int?
        let height: Int?
        let codedWidth: Int?
        let codedHeight: Int?
        let sampleAspectRatio: String?
        let displayAspectRatio: String?
        let pixFmt: String?
        let level: Int?
        let colorRange: String?
        let colorSpace: String?
        let colorTransfer: String?
        let colorPrimaries: String?
        let chromaLocation: String?
        let fieldOrder: String?
        let refs: Int?
        let sampleFmt: String?
        let sampleRate: String?
        let channels: Int?
        let channelLayout: String?
        let bitsPerSample: Int?
        let rFrameRate: String?
        let avgFrameRate: String?
        let timeBase: String?
        let startPts: Int?
        let startTime: String?
        let duration: String?
        let bitRate: String?
        let nbFrames: String?
        let formatLongName: String?
        
        enum CodingKeys: String, CodingKey {
            case index, profile, level, refs, duration
            case codecType = "codec_type"
            case codecName = "codec_name"
            case codecLongName = "codec_long_name"
            case codecTagString = "codec_tag_string"
            case codecTag = "codec_tag"
            case width, height
            case codedWidth = "coded_width"
            case codedHeight = "coded_height"
            case sampleAspectRatio = "sample_aspect_ratio"
            case displayAspectRatio = "display_aspect_ratio"
            case pixFmt = "pix_fmt"
            case colorRange = "color_range"
            case colorSpace = "color_space"
            case colorTransfer = "color_transfer"
            case colorPrimaries = "color_primaries"
            case chromaLocation = "chroma_location"
            case fieldOrder = "field_order"
            case sampleFmt = "sample_fmt"
            case sampleRate = "sample_rate"
            case channels
            case channelLayout = "channel_layout"
            case bitsPerSample = "bits_per_sample"
            case rFrameRate = "r_frame_rate"
            case avgFrameRate = "avg_frame_rate"
            case timeBase = "time_base"
            case startPts = "start_pts"
            case startTime = "start_time"
            case bitRate = "bit_rate"
            case nbFrames = "nb_frames"
            case formatLongName = "format_long_name"
        }
    }

    struct FFprobeFormat: Codable {
        let filename: String
        let nbStreams: Int
        let formatName: String
        let formatLongName: String?
        let startTime: String?
        let duration: String?
        let size: String?
        let bitRate: String?
        
        enum CodingKeys: String, CodingKey {
            case filename, duration, size
            case nbStreams = "nb_streams"
            case formatName = "format_name"
            case formatLongName = "format_long_name"
            case startTime = "start_time"
            case bitRate = "bit_rate"
        }
    }

    
    
    init() {
        self.ffprobeURL = nil
        if !checkFFprobe() {
            _ = Constants.dropAlert(message: "ffprobe is missing", informative: "Some info will not be available until you install ffprobe binary in Resources folder of the app.\nIf ffprobe is located in /usr/local/bin/ffprobe, copy the binary in the Resources folder of the app.")
        }
        
        self.ffmpegURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil)
    }
    
    
    
    //MARK: Check if file is a valid media file and return file metadata
    func isAVMediaType(url: URL) -> (isPlayable: Bool, formats: [String: Any]) {
        let urlAsset = AVURLAsset(url: url)
        if urlAsset.isPlayable {
            format = getMetadata(asset: urlAsset)
            return (isPlayable: true, formats: format)
        }
        
        if isValidFFmpegCandidate(url, checkFileExists: true ) {
            do {
                let jsonData = try getFFprobeJSON(for: url)
                let ffprobeOutput = String(decoding: jsonData, as: UTF8.self)
                print("JSONDATA: \(ffprobeOutput)")
                do {
                    let formatDescriptions = try createFormatDescriptions(from: jsonData)
                    var format: [String:Any] = [:]
                    print("Format Desc: \(formatDescriptions)")
                    for desc in formatDescriptions {
                        switch CMFormatDescriptionGetMediaType(desc) {
                            case kCMMediaType_Video:
                                format["videoDesc"] = desc
                                format["rate"] = getFrameRate(jsonData)  //Float(0.0)
                                format["icon"] = "video"
                                break
                                
                            case kCMMediaType_Audio:
                                format["audioDesc"] = desc
                                format["icon"] = "hifispeaker"
                                break
                                
                            case kCMMediaType_TimeCode:
                                format["tcDesc"] = desc
                                break
                            
                            default:
                                return (isPlayable: false, formats: [:])
                            
                        }
                    }
                    
                    return (isPlayable: true, formats: format)
                    
                } catch {
                    return (isPlayable: false, formats: [:])
                }
                
            } catch {
                return (isPlayable: false, formats: [:])
            }
        }
        
        return (isPlayable: false, formats: [:])
    }
    
    
    func getFrameRate(_ data: Data) -> Float {
        let decoder = JSONDecoder()
        var res: Float = 0.0
        do {
            let ffprobeOutput = try decoder.decode(FFprobeOutput.self, from: data)
            print("ffprobeOutput: \(ffprobeOutput.streams[0].rFrameRate!)")
            if let numbers = ffprobeOutput.streams[0].rFrameRate!.components(separatedBy: "/") {
                res = Float(numbers.first) / Float(numbers.last)
            }
        } catch {
            print("ERROR")
        }
        
        return res
    }
    
    
    
    func getMetadata(asset: AVURLAsset ) -> [String: Any] {
        var videoFormatDesc: CMVideoFormatDescription?
        var audioFormatDesc: CMAudioFormatDescription?
        var timeFromatDesc: CMTimeCodeFormatDescription?
        
        var formats: [String:Any] = [:]
        for track in asset.tracks {
            switch track.mediaType {
            case .video:
                videoFormatDesc = ((track.formatDescriptions[0] ) as! CMVideoFormatDescription)
                // print("Video Format Desc: \(videoFormatDesc)")
                formats["videoDesc"] = videoFormatDesc
                formats["rate"] = track.nominalFrameRate
                formats["icon"] = "video"
                break
            case .audio:
                audioFormatDesc = ((track.formatDescriptions[0] ) as! CMAudioFormatDescription)
//                print("Audio Format Desc: \(audioFormatDesc)")
                
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
    
    
    func getFFprobeJSON(for url: URL) throws -> Data {
        let process = Process()
        process.executableURL = ffprobeURL // URL(fileURLWithPath: "/usr/local/bin/ffprobe")
        process.arguments = [
            "-v", "quiet",
            "-show_format",
            "-show_streams",
            "-print_format", "json",
            url.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return data
    }
    
    
    func checkFFprobeFile(for url: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = ffprobeURL  //URL(fileURLWithPath: "/usr/local/bin/ffprobe")
        process.arguments = [
            "-ss",
            "00:29:59",
            "-i",
            url.path,
            "-f",
            "null",
            "-"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
            
        return process.terminationStatus
    }
    
    
    
    func isValidFFmpegCandidate(_ fileURL: URL, checkFileExists: Bool = true) -> Bool {
        // Optional file existence check
        if checkFileExists && fileURL.isFileURL {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return false
            }
            
            // Check if it's actually a file (not a directory)
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
            guard !isDirectory.boolValue else {
                return false
            }
        }
        
        let fileExtension = fileURL.pathExtension.lowercased()
        
        guard !fileExtension.isEmpty else {
            return false
        }
        
        return Constants.ffmpegSupportedExtensions.contains(fileExtension)
    }
    // MARK: - Conversion Functions

    enum FormatDescriptionError: Error {
        case unsupportedCodec(String)
        case missingRequiredField(String)
        case invalidData
        case creationFailed
    }

    
    
    // MARK: - Format Descriptions
    
    func createFormatDescriptions(from jsonData: Data) throws -> [CMFormatDescription] {
        let decoder = JSONDecoder()
        let ffprobeOutput = try decoder.decode(FFprobeOutput.self, from: jsonData)
        
        var formatDescriptions: [CMFormatDescription] = []
        
        for stream in ffprobeOutput.streams {
            if let formatDesc = try? createFormatDescription(from: stream) {
                formatDescriptions.append(formatDesc)
            }
        }
        
        return formatDescriptions
    }

    
    
    func createFormatDescription(from stream: FFprobeStream) throws -> CMFormatDescription {
        switch stream.codecType {
        case "video":
            return try createVideoFormatDescription(from: stream)
        case "audio":
            return try createAudioFormatDescription(from: stream)
        default:
            throw FormatDescriptionError.unsupportedCodec(stream.codecType)
        }
    }

    
    
    
    // MARK: - Video Format Description

    func createVideoFormatDescription(from stream: FFprobeStream) throws -> CMFormatDescription {
        guard let width = stream.width, let height = stream.height else {
            throw FormatDescriptionError.missingRequiredField("width or height")
        }
        
        let codecType = fourCharCode(from: stream.codecName)
        var formatDescription: CMFormatDescription?
        
        var extensions: [String: Any] = [:]
        
        if let avg_frame_rate = stream.avgFrameRate {
            extensions["AvgFrameRate"] = avg_frame_rate
        }
        
        if let formatName = stream.codecLongName {
            extensions["FormatName"] = formatName
        }
        // Add color information if available
        if let colorPrimaries = stream.colorPrimaries {
            extensions[kCVImageBufferColorPrimariesKey as String] = colorPrimaries
        }
        if let colorTransfer = stream.colorTransfer {
            extensions[kCVImageBufferTransferFunctionKey as String] = colorTransfer
        }
        if let colorSpace = stream.colorSpace {
            extensions[kCVImageBufferYCbCrMatrixKey as String] = colorSpace
        }
        
        // Parse pixel aspect ratio
        if let sarString = stream.sampleAspectRatio, sarString != "0:1" {
            let components = sarString.split(separator: ":")
            if components.count == 2,
               let hSpacing = Int(components[0]),
               let vSpacing = Int(components[1]) {
                extensions[kCVImageBufferPixelAspectRatioKey as String] = [
                    kCVImageBufferPixelAspectRatioHorizontalSpacingKey as String: hSpacing,
                    kCVImageBufferPixelAspectRatioVerticalSpacingKey as String: vSpacing
                ]
            }
        }
        
        let extensionDict = extensions.isEmpty ? nil : extensions as CFDictionary
        
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: codecType,
            width: Int32(width),
            height: Int32(height),
            extensions: extensionDict,
            formatDescriptionOut: &formatDescription
        )
        
        guard status == noErr, let formatDesc = formatDescription else {
            throw FormatDescriptionError.creationFailed
        }
        
        return formatDesc
    }

    
    
    // MARK: - Audio Format Description

    func createAudioFormatDescription(from stream: FFprobeStream) throws -> CMFormatDescription {
        guard let sampleRateString = stream.sampleRate,
              let sampleRate = Double(sampleRateString) else {
            throw FormatDescriptionError.missingRequiredField("sample_rate")
        }
        
        let channels = UInt32(stream.channels ?? 2)
        let codecType = fourCharCode(from: stream.codecName)
        
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = sampleRate
        asbd.mFormatID = codecType
        asbd.mChannelsPerFrame = channels
        
        // Set additional properties based on codec
        switch stream.codecName {
        case "pcm_s16le", "pcm_s16be":
            asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
            asbd.mBitsPerChannel = 16
            asbd.mBytesPerFrame = 2 * channels
            asbd.mFramesPerPacket = 1
            asbd.mBytesPerPacket = asbd.mBytesPerFrame
        case "pcm_s24le", "pcm_s24be":
            asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
            asbd.mBitsPerChannel = 24
            asbd.mBytesPerFrame = 3 * channels
            asbd.mFramesPerPacket = 1
            asbd.mBytesPerPacket = asbd.mBytesPerFrame
        case "pcm_f32le", "pcm_f32be":
            asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
            asbd.mBitsPerChannel = 32
            asbd.mBytesPerFrame = 4 * channels
            asbd.mFramesPerPacket = 1
            asbd.mBytesPerPacket = asbd.mBytesPerFrame
        case "aac":
            asbd.mFramesPerPacket = 1024
        default:
            // Generic compressed format
            asbd.mFramesPerPacket = 0
        }
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        guard status == noErr, let formatDesc = formatDescription else {
            throw FormatDescriptionError.creationFailed
        }
        
        return formatDesc
    }

    // MARK: - Helper Functions

    func fourCharCode(from codecName: String) -> CMVideoCodecType {
        // Map common FFmpeg codec names to FourCC codes
        switch codecName.lowercased() {
        case "h264", "avc1":
            return kCMVideoCodecType_H264
        case "hevc", "h265":
            return kCMVideoCodecType_HEVC
//        case "vp8":
//            return kCMVideoCodecType_VP8
        case "vp9":
            return kCMVideoCodecType_VP9
        case "mpeg4":
            return kCMVideoCodecType_MPEG4Video
        case "mpeg2video":
            return kCMVideoCodecType_MPEG2Video
        case "mpeg1video":
            return kCMVideoCodecType_MPEG1Video
        case "mjpeg", "jpeg":
            return kCMVideoCodecType_JPEG
        case "prores":
            return kCMVideoCodecType_AppleProRes422
//        case "dnxhd":
//            return CMVideoCodecType(kCMVideoCodecType_DVCPROHD)
//        case "aac":
//            return kAudioFormatMPEG4AAC
//        case "mp3":
//            return kAudioFormatMPEGLayer3
//        case "pcm_s16le", "pcm_s16be":
//            return kAudioFormatLinearPCM
//        case "pcm_f32le", "pcm_f32be":
//            return kAudioFormatLinearPCM
//        case "flac":
//            return kAudioFormatFLAC
//        case "alac":
//            return kAudioFormatAppleLossless
//        case "opus":
//            return kAudioFormatOpus
//        case "vorbis":
//            return kAudioFormatVorbis
        default:
            // Try to convert string to FourCC
            let chars = Array(codecName.prefix(4).padding(toLength: 4, withPad: " ", startingAt: 0))
            return FourCharCode(chars[0].asciiValue ?? 0) << 24 |
                   FourCharCode(chars[1].asciiValue ?? 0) << 16 |
                   FourCharCode(chars[2].asciiValue ?? 0) << 8 |
                   FourCharCode(chars[3].asciiValue ?? 0)
        }
    }
    

}



// MARK: - Usage Example
/*
func processFFprobeOutput(jsonData: Data) {
    do {
        let formatDescriptions = try createFormatDescriptions(from: jsonData)
        
        for (index, formatDesc) in formatDescriptions.enumerated() {
            print("Stream \(index):")
            
            if CMFormatDescriptionGetMediaType(formatDesc) == kCMMediaType_Video {
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
                print("  Type: Video")
                print("  Dimensions: \(dimensions.width)x\(dimensions.height)")
                print("  Codec: \(CMFormatDescriptionGetMediaSubType(formatDesc).toString())")
            } else if CMFormatDescriptionGetMediaType(formatDesc) == kCMMediaType_Audio {
                if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
                    print("  Type: Audio")
                    print("  Sample Rate: \(asbd.pointee.mSampleRate) Hz")
                    print("  Channels: \(asbd.pointee.mChannelsPerFrame)")
                    print("  Codec: \(asbd.pointee.mFormatID.toString())")
                }
            }
        }
    } catch {
        print("Error processing FFprobe output: \(error)")
    }
}

*/


/*
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
                do {
                    if let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("CMFD: \(dictionary)")
                        return (isPlayable: true, formats: dictionary)
                    } catch {
                        print("Failed to parse JSON: $$error.localizedDescription)")
                    } catch {
                        print("Failed to run process: $$error)")
                    }
                } catch {
                    print("Failed to run process: $$error)")
                }
            }
        }
*/
        
