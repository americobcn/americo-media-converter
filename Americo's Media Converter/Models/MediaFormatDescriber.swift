import AVFoundation

enum MediaFormatDescriber {

    // MARK: - Format Descriptions
    static func getFormatDescription(_ formatDescription: [String: Any]) -> String {
        var description: String = ""
        for (key, _) in formatDescription {
            if key == "videoDesc" {
                description += getVideoTrackDescription(videoFormatDesc: formatDescription["videoDesc"] as! CMFormatDescription,
                                                        rate: formatDescription["rate"] as! Float)
            } else if key == "audioDesc" {
                description += getAudioTrackDescription(audioFormatDesc: formatDescription["audioDesc"] as! CMFormatDescription)
            }
        }

        return description
    }


    static func getVideoTrackDescription(videoFormatDesc: CMFormatDescription, rate: Float) -> String {
        var movieDepth: CFPropertyList?
        var interlacedPregressive = ""
        var videoDescription: String = ""
        var movieColorPrimaries = ""
        var movieCodec = ""
        let mediaSubType = CMFormatDescriptionGetMediaSubType(videoFormatDesc).toString()

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

    static func getAudioTrackDescription(audioFormatDesc: CMFormatDescription) -> String {
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

    static func formatSecondsTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, seconds >= 0 else {
            return "00:00:00"
        }

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

}


// MARK: - Extensions
extension FourCharCode {
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
