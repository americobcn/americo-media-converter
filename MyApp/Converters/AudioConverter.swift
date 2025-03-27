//
//  AudioConverter.swift
//  ffmpegui
//
//  Created by Berlin on 19/3/25.
//

import Foundation


protocol AudioConverterDelegate: AnyObject {
    func shouldUpdateAudioOutView(_ converter: AudioConverter, _ text: String)
}

class AudioConverter {
    var delegate: AudioConverterDelegate?
    
    let lamePath: String
    let ffmpegPath: String
    let afconvertPath: String
    var converter: String = ""
    
    init(lamePath: String = "/usr/local/bin/lame", ffmpegPath: String = "/usr/local/bin/ffmpeg", afconvert: String = "/usr/bin/afconvert",
         delegate: AudioConverterDelegate) {
        self.lamePath = lamePath
        self.ffmpegPath = ffmpegPath
        self.converter = lamePath
        self.afconvertPath = afconvert
        self.delegate = delegate
    }
    
    
    func convertAudio(file: String, codec: String,  args: String, completion: @escaping (Bool, String?) -> Void) {
        var newExtension: String = ""
        var options: Array<String> = []
        switch codec {
        case "WAV":
            converter = ffmpegPath
            newExtension = codec.lowercased()
            options.append("-i")
            break
        case "AAC":
            converter = ffmpegPath
            newExtension = "m4a"
            options.append("-i")
            break
        case "MP3":
            converter = lamePath
            newExtension = codec.lowercased()
            break
        default:
            break
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: converter)
        
        let outPath = changeFileExtension(of: file, to: newExtension)
        
        options.append(file)
        options.append(contentsOf: args.components(separatedBy: .whitespaces))
        options.append(contentsOf: [outPath])
        process.arguments = options
        
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        let fileHandle = outputPipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let output = String(data: data, encoding: .ascii), !output.isEmpty else { return }
            DispatchQueue.main.async {
                self?.delegate?.shouldUpdateAudioOutView(self!, output)
            }
        }
        
        process.terminationHandler = { _ in
            let status = process.terminationStatus
            completion(status == 0, status == 0 ? nil : "Conversion failed with status code \(status).")
        }
        
        do {
            try process.run()
        } catch {
            completion(false, "Failed to start conversion process: \(error.localizedDescription)")
        }
        
    }
    
    
    /* PRIVATE FUNCTIONS */
    private func changeFileExtension(of filePath: String, to newExtension: String) -> String {
        let url = URL(fileURLWithPath: filePath)
        let newUrl = url.deletingPathExtension().appendingPathExtension(newExtension.lowercased())
        return newUrl.path
    }
    
}



