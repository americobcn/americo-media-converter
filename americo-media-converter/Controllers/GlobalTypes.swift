//
//  GlobalTypes.swift
//  americo-media-converter
//
//  Created by Lisboa on 9/10/25.
//

import Cocoa

enum ConversionType {
    case audio
    case video
}


enum MessageAttribute {
    case regular
    case error
    case succes
}


let regularMessageAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12),
    .foregroundColor: NSColor.lightGray
]

let errorMessageAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12),
    .foregroundColor: NSColor.red
]

let succesMessageAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12),
    .foregroundColor: NSColor.green
]
