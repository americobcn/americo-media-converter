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
        
        if isValidFFmpegCandidate(url) {
            do {
                let jsonData = try getFFprobeJSON(for: url)
                 let ffprobeOutput = String(decoding: jsonData, as: UTF8.self)
                 print("JSONDATA: \(ffprobeOutput)")
                do {
                    let formatDescriptions = try createFormatDescriptions(from: jsonData)
                    var format: [String:Any] = [:]
//                    print("Format Desc: \(formatDescriptions)")
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
        do {
            let ffprobeOutput = try decoder.decode(FFprobeOutput.self, from: data)
//            print("ffprobeOutput frame rate: \(ffprobeOutput.streams[0].rFrameRate!)")
            let formula = ffprobeOutput.streams[0].rFrameRate
            let nums = formula!.split(separator: "/")
//            print("nums: \(nums)")
            let num1 = Float(nums[0])!
            let num2 = Float(nums[1])!
//            print("FPS: \(num1 / num2)")
            return num1 / num2
            
        } catch {
            print("ERROR")
        }
        
        return 0.0
    }
    
    
    
    func getMetadata(asset: AVURLAsset ) -> [String: Any] {
        var videoFormatDesc: CMVideoFormatDescription?
        var audioFormatDesc: CMAudioFormatDescription?
        var timeFromatDesc: CMTimeCodeFormatDescription?
        
        var format: [String:Any] = [:]        
        for track in asset.tracks {
            switch track.mediaType {
            case .video:
                videoFormatDesc = ((track.formatDescriptions[0] ) as! CMVideoFormatDescription)
                print("Video Format Desc: \(String(describing: videoFormatDesc))")
                format["videoDesc"] = videoFormatDesc
                format["rate"] = track.nominalFrameRate
                format["icon"] = "video"
                break
            case .audio:
                audioFormatDesc = ((track.formatDescriptions[0] ) as! CMAudioFormatDescription)
                print("Audio Format Desc: \(String(describing: audioFormatDesc))")
                
                format["audioDesc"] = audioFormatDesc
                format["icon"] = "hifispeaker"
                break
            case .timecode:
                timeFromatDesc = ((track.formatDescriptions[0]) as! CMTimeCodeFormatDescription)
                format["tcDesc"] = timeFromatDesc
            default:
                break
            }
        }
        // print("TC Frame Rate: \(timeFromatDesc?.frameQuanta ?? 0)")
        return  format
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
        
        return Constants.playableFileExt.contains(fileExtension)
//        return Constants.ffmpegSupportedExtensions.contains(fileExtension)
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
        
//        let codecType = fourCharCode(from: stream.codecName)
        guard let codecType = fourCharCode(from: stream.codecName) else {
            throw FormatDescriptionError.creationFailed
        }

        
        var formatDescription: CMFormatDescription?
        
        var extensions: [String: Any] = [:]
        
        if let fieldOrder = stream.fieldOrder {
            extensions["FieldOrder"] = fieldOrder
        }
        
        if stream.fieldOrder == "progressive" {
            extensions["CVFieldCount"] = 1
        } else {
            extensions["CVFieldCount"] = 2
        }
        
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
        if let sar = parseSampleAspectRatio(stream.sampleAspectRatio) {
            // Use sar.numerator and sar.denominator safely
            print("SAR: \(sar.numerator):\(sar.denominator)")
            let hSpacing = Int(sar.numerator)
            let vSpacing = Int(sar.denominator)
            extensions[kCVImageBufferPixelAspectRatioKey as String] = [
                 kCVImageBufferPixelAspectRatioHorizontalSpacingKey as String: hSpacing,
                 kCVImageBufferPixelAspectRatioVerticalSpacingKey as String: vSpacing
             ]
        }
        
//        if let sarString = stream.sampleAspectRatio, sarString != "0:1" {
//            let components = sarString.split(separator: ":")
//            if components.count == 2,
//               let hSpacing = Int(components[0]),
//               let vSpacing = Int(components[1]) {
//                extensions[kCVImageBufferPixelAspectRatioKey as String] = [
//                    kCVImageBufferPixelAspectRatioHorizontalSpacingKey as String: hSpacing,
//                    kCVImageBufferPixelAspectRatioVerticalSpacingKey as String: vSpacing
//                ]
//            }
//        }
        
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
//        let codecType = fourCharCode(from: stream.codecName)
        guard let codecType = fourCharCode(from: stream.codecName) else {
            throw FormatDescriptionError.creationFailed
        }

        
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = sampleRate
        asbd.mChannelsPerFrame = channels
        
        // Set additional properties based on codec
        switch stream.codecName {
        case "pcm_s16le", "pcm_s16be":
            asbd.mFormatID = "lpcm".toFourCharCode()!
            asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
            asbd.mBitsPerChannel = 16
            asbd.mBytesPerFrame = 2 * channels
            asbd.mFramesPerPacket = 1
            asbd.mBytesPerPacket = asbd.mBytesPerFrame
            break
        case "pcm_s24le", "pcm_s24be":
            asbd.mFormatID = "lpcm".toFourCharCode()!
            asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
            asbd.mBitsPerChannel = 24
            asbd.mBytesPerFrame = 3 * channels
            asbd.mFramesPerPacket = 1
            asbd.mBytesPerPacket = asbd.mBytesPerFrame
            break
        case "pcm_f32le", "pcm_f32be":
            asbd.mFormatID = "lpcm".toFourCharCode()!
            asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
            asbd.mBitsPerChannel = 32
            asbd.mBytesPerFrame = 4 * channels
            asbd.mFramesPerPacket = 1
            asbd.mBytesPerPacket = asbd.mBytesPerFrame
            break
        case "aac":
            asbd.mFramesPerPacket = 1024
            break
        default:
            // Generic compressed format
            asbd.mFormatID = codecType
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

    func fourCharCode(from codecName: String) -> CMVideoCodecType? {
        // Map common FFmpeg codec names to FourCC codes
        switch codecName.lowercased() {
            case "h264", "avc1", "h264_mp4", "h264_nal":
                return kCMVideoCodecType_H264
            case "hevc", "h265":
                return kCMVideoCodecType_HEVC
            case "vp9":
                return kCMVideoCodecType_VP9
            case "mpeg4", "mpeg4_part2":
                return kCMVideoCodecType_MPEG4Video
            case "mpeg2video":
                return kCMVideoCodecType_MPEG2Video
            case "mpeg1video":
                return kCMVideoCodecType_MPEG1Video
            case "mjpeg", "jpeg":
                return kCMVideoCodecType_JPEG
            case "prores":
                return kCMVideoCodecType_AppleProRes422
            default:
                // Try to convert string to FourCC
            let chars = Array(codecName.prefix(4).padding(toLength: 4, withPad: " ", startingAt: 0))
            return FourCharCode(chars[0].asciiValue ?? 0) << 24 |
                FourCharCode(chars[1].asciiValue ?? 0) << 16 |
                FourCharCode(chars[2].asciiValue ?? 0) << 8 |
                FourCharCode(chars[3].asciiValue ?? 0)
        }
    }
    
    
    
    private func parseSampleAspectRatio(_ aspectRatioString: String?) -> (numerator: Int, denominator: Int)? {        
        guard let sarString = aspectRatioString,
              !sarString.isEmpty,
              sarString != "0:1" else {
            return nil
        }
        
        let components = sarString.split(separator: ":").compactMap { Int($0) }
        
        guard components.count == 2,
              components[1] > 0 else {
            return nil
        }
        
        return (numerator: components[0], denominator: components[1])
    }
}

