import Foundation
import Cocoa

protocol VideoConverterDelegate: AnyObject {
    func shouldUpdateVideoOutView( _ text: String)
}


class VideoConverter {
    var delegate: VideoConverterDelegate?
    
    let ffmpegPath: String
    init(ffmpegPath: String = "/usr/local/bin/ffmpeg") {
        self.ffmpegPath = ffmpegPath
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
    
    func convertVideo(fileURL: URL,
                      args: String,
                      textView: NSTextView,
                      container: String,
                      completion: @escaping (Bool, String?) -> Void
    ) {
        textView.textStorage?.setAttributedString(NSAttributedString(string: "Started Converting Video", attributes: self.normalMessageAttributes))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        
        var arguments = ["-i", fileURL.path]
        arguments.append(contentsOf: args.components(separatedBy: .whitespaces))
        
        let newUrl = fileURL.deletingPathExtension().appendingPathExtension(container.lowercased())
        arguments.append(newUrl.path)
        process.arguments = arguments
        // print(process.arguments)
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
                self?.delegate?.shouldUpdateVideoOutView(output)
                print(output)
            }
        }
        
        
        process.terminationHandler = { _ in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                switch status {
                case 0:
                    textView.textStorage?.append(NSAttributedString(string: "\nSuccess converting \(fileURL.path).\n", attributes: self.succesMessageAttributes))
                default:
                    textView.textStorage?.append(NSAttributedString(string: "\nError converting \(fileURL), failed with status code \(status).\n", attributes: self.errorMessageAttributes))
                }
            }
            completion(status == 0, status == 0 ? "Success converting \(fileURL)." : "Error converting \(fileURL), failed with status code \(status).")
        }

        
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                textView.textStorage?.append(NSAttributedString(string: "\(fileURL): Failed to start conversion process: \(error.localizedDescription)", attributes: self.errorMessageAttributes))
            }
            completion(false, "\n\(fileURL): Failed to start conversion process: \(error.localizedDescription)")
        }
            
    }
}

