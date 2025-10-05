//
//  AudioConverter.swift
//  
//
//  Created by Américo on 19/3/25.
//

// import Foundation
import Cocoa

protocol AudioConverterDelegate: AnyObject {
    func shouldUpdateAudioOutView( _ text: String)
}

class AudioConverter {
    var delegate: AudioConverterDelegate?
    
    let ffmpegPath: String
    let afconvertPath: String
    var converter: String = ""
    
    var succesFiles: [String] = []
    var errorFiles: [String] = []
    
    let errorMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.red
    ]
    
    let succesMessageAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.green
    ]
    
    init(ffmpegPath: String = "/usr/local/bin/ffmpeg",
         afconvert: String = "/usr/bin/afconvert",
         delegate: AudioConverterDelegate
    ) {
        self.ffmpegPath = ffmpegPath
        self.afconvertPath = afconvert
        self.delegate = delegate
    }
    
    func convertAudio(file: URL,
                      codec: String,
                      args: String,
                      destinationFolder: String?,
                      completion: @escaping (Bool, String) -> Void
    ) {
        var newExtension: String = ""
        var options: Array<String> = []
        switch codec {
        case "MP3":
            converter = ffmpegPath
            options.append("-i")
            newExtension = codec.lowercased()
            break
        default:
            converter = afconvertPath
            if codec == "AAC" {
                newExtension = "m4a"
            } else {
                newExtension = codec.lowercased()
            }
            break
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: converter)
        
        
        let outPath = composeFileURL(of: file, to: newExtension, destinationFolder)
        
        options.append(file.path)
        options.append(contentsOf: args.components(separatedBy: .whitespaces))
        options.append(contentsOf: [outPath])
        process.arguments = options
        print(options)
        
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        let fileHandle = outputPipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
            DispatchQueue.main.async {
                self?.delegate?.shouldUpdateAudioOutView(output)
            }
        }
        
        process.terminationHandler = { _ in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                switch status {
                case 0:
                    self.delegate?.shouldUpdateAudioOutView("\nSuccess converting \(file.path).\n")
                default:
                    self.delegate?.shouldUpdateAudioOutView("\nError converting \(file), failed with status code \(status).\n")
                }
            }
            // completion(status == 0, status == 0 ? "Success converting \(file)." : "Error converting \(file), failed with status code \(status).")
        }
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateAudioOutView("\(file): Failed to start conversion process: \(error.localizedDescription)")
            }
            // completion(false, "\n\(file): Failed to start conversion process: \(error.localizedDescription)")
        }
    }
    
    
    /* PRIVATE FUNCTIONS */
    private func composeFileURL(of filePath: URL, to newExtension: String, _ destinationFolder: String?) -> String {
        if destinationFolder != nil {
            let url = URL(fileURLWithPath: destinationFolder! + "/" + filePath.lastPathComponent)
            let newUrl = url.deletingPathExtension().appendingPathExtension(newExtension)
            return newUrl.path
        }

        let newUrl = filePath.deletingPathExtension().appendingPathExtension(newExtension)
        return newUrl.path
    }
}
