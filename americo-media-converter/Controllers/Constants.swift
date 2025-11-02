import Cocoa
import AVFoundation

struct Constants {
    static let supportedFileExt: [AVMediaType: [String]] = [
      .video: ["mp4", "m4v", "mkv", "webm", "mov", "avi", "wmv", "flv", "f4v",
               "swf", "mpg", "mpeg", "m2v", "3gp", "3g2", "mxf", "roq", "nsv",
               "vob", "ogv", "drc", "gifv", "mng", "qt", "yuv", "rm", "rmvb",
               "asf", "amv", "m4p", "mpv", "mp2", "mpe", "mpv2", "m2ts", "mts",
               "ts", "divx", "dv", "gxf", "mj2", "mjpeg", "mjpg", "nut", "rv",
               "wtv", "dvr-ms", "rec", "mod", "tod", "vro"],
      
      .audio: ["mp3", "aac", "wav", "flac", "ogg", "oga", "opus", "wma", "m4a",
               "ac3", "eac3", "dts", "ape", "wv", "tta", "tak", "aiff", "aif",
               "aifc", "au", "snd", "amr", "awb", "mp2", "mpa", "m4b", "m4r",
               "3ga", "ra", "ram", "spx", "voc", "w64", "xa", "caf", "gsm",
               "mlp", "mka", "shn", "vqf", "aa", "aa3", "aax", "act", "alac",
               "mogg", "wv", "ape", "tta", "tak"],
    ]
    
    static let playableFileExt = supportedFileExt[.video]! + supportedFileExt[.audio]!
    
    /// I know, not constatnts -\_/-. DON'T HATE ME
    static private(set) var HasLibfdkAAC = false
    static private(set) var aacCodec = "aac"
    
    static private(set) var hasLibx264 = false
    static private(set) var h264Codec = "h264"

    enum ConversionType {
        case audio
        case video
    }
    
    struct MessageAttribute {
        static let regularMessageAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.lightGray
        ]

        static let errorMessageAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.red
        ]

        static let succesMessageAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.green
        ]
    }
    

    
    //MARK: Helper funcions
    static func dropAlert(message: String, informative: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informative
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal() // == .alertFirstButtonReturn
    }
    
    
    static func checkBinary(binary: String) -> URL {
        // First, try to find the binary in the app bundle
        if let url = Bundle.main.url(forResource: binary, withExtension: nil) {
            self.HasLibfdkAAC = ffmpegHasLibfdkAAC(ffmpegURL: url)
            self.hasLibx264 = ffmpegHasLibx264(ffmpegURL: url)
            return url
        }
        
        // If not found in bundle, search system paths
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [binary]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                let url = URL(fileURLWithPath: path)
                self.HasLibfdkAAC = ffmpegHasLibfdkAAC(ffmpegURL: url)
                return url
            }
        } catch {
            print("Error checking for ffmpeg: \(error)")
            self.dropAlert(message: "Error", informative: "Failed to locate \(binary). Please add it to your PATH.")
        }
        
        // NOT VALID RETURN; JUST TO TEST
        return URL(fileReferenceLiteralResourceName: "")
    }
    

    static func ffmpegHasLibfdkAAC(ffmpegURL: URL ) -> Bool {
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = ["-hide_banner", "-encoders"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return false
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: outputData, encoding: .utf8) else {
            return false
        }

        let pattern = #"libfdk_aac\s+Fraunhofer FDK AAC"#
        if output.range(of: pattern, options: .regularExpression) != nil {
            self.aacCodec = "libfdk_aac"
        }

        return output.range(of: pattern, options: .regularExpression) != nil
    }
    
    static func ffmpegHasLibx264(ffmpegURL: URL ) -> Bool {
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = ["-hide_banner", "-encoders"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return false
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: outputData, encoding: .utf8) else {
            return false
        }

//        let pattern = #"libx264\s+libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10"#
        let pattern = #"libx264\s+libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4"#
        if output.range(of: pattern, options: .regularExpression) != nil {
            self.h264Codec = "libx264"
        }

        return output.range(of: pattern, options: .regularExpression) != nil
    }
}
