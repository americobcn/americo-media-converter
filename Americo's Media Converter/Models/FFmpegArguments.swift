import Foundation

enum FFmpegArguments {

    // MARK: - Audio
    static func audio(type: AudioTypes, bits: String, sampleRate: String, aacCodec: String) -> String {
        switch type {
        case .WAV:
            if bits == "24" {
                return "-y -sample_fmt s32 -c:a pcm_s\(bits)le -ar \(sampleRate)"
            }
            return "-y -sample_fmt s\(bits) -c:a pcm_s\(bits)le -ar \(sampleRate)"

        case .AAC:
            let bufferSize = (Int(bits) ?? 0) * 2
            return "-y -vn -c:a \(aacCodec) -b:a \(bits)k -maxrate \(bits)k -bufsize \(bufferSize)k -ar \(sampleRate)"

        case .MP3:
            return "-y -codec:a libmp3lame -b:a \(bits)k -ar \(sampleRate)"
        }
    }


    // MARK: - Video
    static func video(codec: VideoCodecs,
                      profileTitle: String,
                      resolution videoResolution: VideoResolution,
                      frameRate: VideoFrameRates,
                      pad isPadded: Bool,
                      hasLibx264: Bool,
                      aacCodec: String) -> String {
        let profiles = VideoProfiles(rawValue: codec.rawValue) ?? .ProRes
        let profile = profiles.profiles.first(where: { $0.title == profileTitle })?.profile ?? ""
        let resolution = videoResolution.ffmpegString
        let pad = isPadded ? ",pad=\(resolution):(ow-iw)/2:(oh-ih)/2" : ""

        let pixFmt: String
        switch profile {
        case "dnxhr_hqx", "0", "1", "2", "3":
            pixFmt = "yuv422p10le"
            break
        case "dnxhr_444":
            pixFmt = "yuv444p10le"
            break
        case "4", "5":
            pixFmt = "yuva444p10le"
            break
        default:
            pixFmt = "yuv422p"
            break
        }

        let newFPS: String
        switch frameRate.rawValue {
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
            newFPS = ",fps=\(frameRate.rawValue)"
            break
        }

        let h264Arguments = hasLibx264 ? "-c:v libx264 -profile:v high422 -preset slow -crf 18" : "-c:v h264"

        switch codec {
        case .ProRes:
            return "-y -c:v prores_ks -profile:v \(profile) -qscale:v 9 -vendor apl0 -pix_fmt \(pixFmt) -vf scale=\(resolution):force_original_aspect_ratio=decrease\(pad)\(newFPS) -c:a pcm_s24le"

        case .H264:
            return "-y \(h264Arguments) -vf format=\(pixFmt),scale=\(resolution):force_original_aspect_ratio=decrease\(pad)\(newFPS) -c:a \(aacCodec) -b:a 320k"

        case .DNxHD:
            return "-y -c:v dnxhd -profile:v \(profile) -pix_fmt \(pixFmt) -vf scale=\(resolution):force_original_aspect_ratio=decrease\(pad)\(newFPS)  -c:a pcm_s24le"
        }
    }
}
