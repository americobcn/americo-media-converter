//
//  GlobalTypes.swift
//  americo-media-converter
//
//  Created by Américo Cot on 9/10/25.
//

import Cocoa

struct Constants {
    static let ffmpegSupportedExtensions: Set<String> = [
        // Video formats
        "mp4", "m4v", "mkv", "webm", "mov", "avi", "wmv", "flv", "f4v",
        "swf", "mpg", "mpeg", "m2v", "3gp", "3g2", "mxf", "roq", "nsv",
        "vob", "ogv", "drc", "gifv", "mng", "qt", "yuv", "rm", "rmvb",
        "asf", "amv", "m4p", "mpv", "mp2", "mpe", "mpv2", "m2ts", "mts",
        "ts", "divx", "dv", "gxf", "mj2", "mjpeg", "mjpg", "nut", "rv",
        "wtv", "dvr-ms", "rec", "mod", "tod", "vro",
        // Audio formats
        "mp3", "aac", "wav", "flac", "ogg", "oga", "opus", "wma", "m4a",
        "ac3", "eac3", "dts", "ape", "wv", "tta", "tak", "aiff", "aif",
        "aifc", "au", "snd", "amr", "awb", "mp2", "mpa", "m4b", "m4r",
        "3ga", "ra", "ram", "spx", "voc", "w64", "xa", "caf", "gsm",
        "mlp", "mka", "shn", "vqf", "aa", "aa3", "aax", "act", "alac"
    ]
    
    
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
    
    
    static func dropAlert(message: String, informative: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informative
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        return alert.runModal() == .alertFirstButtonReturn
    }
    
}
