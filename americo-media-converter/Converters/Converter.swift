//
//  Converter.swift
//  americo-media-converter
//
//  Created by Americo Cot on 5/10/25.
//

import Cocoa


protocol ConverterDelegate: AnyObject {
    func shouldUpdateOutView( _ text: String, _ attr: [NSAttributedString.Key: Any])
}


class Converter {
    var delegate: ConverterDelegate?
    var ffmpegURL: URL!
    
    init(delegate: ConverterDelegate) {
        self.ffmpegURL = nil
        self.delegate = delegate
        setup()
    }
    
    private func setup() {
        if !checkFFmpeg() {
            _ = Constants.dropAlert(message: "ffmpeg is missing", informative: "Install ffmpeg binary in Resources folder of the app.\nIf ffmpeg is located in /usr/local/bin/ffmpeg, copy the binary in the Resources folder of the app.")
            NSApplication.shared.terminate(nil)
        }
                
    }
    
    
    func convert(fileURL: URL,
                 args: String,
                 outPath: String,
                 completion: @escaping (Bool, String?, Int32) -> Void
    ) {
        self.delegate?.shouldUpdateOutView("Start Converting\n", Constants.MessageAttribute.succesMessageAttributes)
        
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
                self?.delegate?.shouldUpdateOutView(output, Constants.MessageAttribute.regularMessageAttributes)
                print(output)
            }
        }
        
        
        process.terminationHandler = { _ in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                switch status {
                case 0:
                    self.delegate?.shouldUpdateOutView("\nSuccess converting \(fileURL.path).\n",  Constants.MessageAttribute.succesMessageAttributes)
                    
                default:
                    self.delegate?.shouldUpdateOutView("\nError converting \(fileURL), failed with status code \(status).\n",  Constants.MessageAttribute.errorMessageAttributes)
                }
            }
        }
        
        do {
            print(process.executableURL ?? "No executable", process.arguments ?? "No args")
            try process.run()
            process.waitUntilExit()
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView("\(fileURL): Failed to start conversion process: \(error.localizedDescription)", Constants.MessageAttribute.errorMessageAttributes)
            }
        }
    }
    
    func checkFFmpeg() -> Bool {
        self.ffmpegURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil)
        if  self.ffmpegURL != nil {
            return true
        } else {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            task.arguments = ["ffmpeg"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if data.isEmpty {
                return false
            }
            
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) {
                self.ffmpegURL = URL(fileURLWithPath: path)
                return true
            } else {
                return false
            }
        }
    }
    
        
    
//    func dropAlert(message: String, informative: String) -> Bool {
//        let alert = NSAlert()
//        alert.messageText = message
//        alert.informativeText = informative
//        alert.alertStyle = .warning
//        alert.addButton(withTitle: "OK")
//        return alert.runModal() == .alertFirstButtonReturn
//    }
    
}
