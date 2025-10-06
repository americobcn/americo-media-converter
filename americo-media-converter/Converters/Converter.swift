//
//  Converter.swift
//  americo-media-converter
//
//  Created by Americo Cot on 5/10/25.
//

import Cocoa

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

protocol ConverterDelegate: AnyObject {
    func shouldUpdateOutView( _ text: String, attr: [NSAttributedString.Key: Any])
}

class Converter {
    var delegate: ConverterDelegate?
    
    let ffmpegURL: URL!
    init(delegate: ConverterDelegate) {
        self.ffmpegURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil)
        self.delegate = delegate
    }
    
    let errorMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.red
    ]
    
    let succesMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.green
    ]
    
    let normalMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.lightGray
    ]
    
    func convert(fileURL: URL,
                 args: String,
                 outPath: String,
                 // container: String?,
                 completion: @escaping (Bool, String?, Int32) -> Void
    ) {
        self.delegate?.shouldUpdateOutView("Start Converting\n", attr: succesMessageAttributes)
        
        let process = Process()
        process.executableURL = ffmpegURL
        
        var arguments = ["-i", fileURL.path]
        arguments.append(contentsOf: args.components(separatedBy: .whitespaces))
        arguments.append(outPath)
        // let newUrl = fileURL.deletingPathExtension().appendingPathExtension(container?.lowercased() ?? "mov")
        // arguments.append(newUrl.path)
        process.arguments = arguments
        print("arguments: \(arguments)")
        let outputPipe = Pipe()
    
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        let fileHandle = outputPipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
            DispatchQueue.main.async {
                self?.delegate?.shouldUpdateOutView(output, attr: regularMessageAttributes)
                print(output)
            }
        }
        
        
        process.terminationHandler = { _ in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                switch status {
                case 0:
                    self.delegate?.shouldUpdateOutView("\nSuccess converting \(fileURL.path).\n", attr: self.succesMessageAttributes)
                    
                default:
                    self.delegate?.shouldUpdateOutView("\nError converting \(fileURL), failed with status code \(status).\n", attr: self.errorMessageAttributes)
                }
            }
            // completion(status == 0, status == 0 ? "Success converting \(fileURL)." : "Error converting \(fileURL), failed with status code \(status).", process.terminationStatus)
        }
                
        do {
            print(process.executableURL ?? "No executable", process.arguments ?? "No args")
            try process.run()
            process.waitUntilExit()
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView("\(fileURL): Failed to start conversion process: \(error.localizedDescription)", attr: self.errorMessageAttributes)
            }
            // completion(false, "\n\(fileURL): Failed to start conversion process: \(error.localizedDescription)", process.terminationStatus)
        }
    }
    

}

