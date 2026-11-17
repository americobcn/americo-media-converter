import Foundation

// MARK: - Conversion Tabs
enum ConversionTab: String, CaseIterable, Identifiable {
    case audio = "Audio"
    case video = "Video"
    case normalize = "Normalize"

    var id: Self { return self }

    var systemImage: String {
        switch self {
        case .audio: return "hifispeaker"
        case .video: return "video"
        case .normalize: return "waveform"
        }
    }
}


// MARK: - Video Options
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


enum VideoContainers: String, CaseIterable, Identifiable {
    case ProRes, DNxHD, H264

    var id: Self { return self }

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

    static func fromDisplayName(_ name: String) -> VideoFrameRates? {
        return allCases.first { $0.displayName == name }
    }
}


// MARK: - Audio Options
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
