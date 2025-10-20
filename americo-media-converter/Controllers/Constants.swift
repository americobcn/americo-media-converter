//
//  GlobalTypes.swift
//  americo-media-converter
//
//  Created by Américo Cot on 9/10/25.
//

import Cocoa

struct Constants {
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
