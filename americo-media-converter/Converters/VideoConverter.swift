import Foundation
import Cocoa

protocol VideoConverterDelegate: AnyObject {
    func shouldUpdateVideoOutView( _ text: String)
}


class VideoConverter {
    var delegate: VideoConverterDelegate?
    
    let ffmpegPath: String
    init(ffmpegPath: String = "/usr/local/bin/ffmpeg",
           delegate: VideoConverterDelegate) {
        self.ffmpegPath = ffmpegPath
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
    
    func convertVideo(fileURL: URL,
                      args: String,                      
                      container: String,
                      completion: @escaping (Bool, String?) -> Void
    ) {
        self.delegate?.shouldUpdateVideoOutView("Started Converting Video")
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
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
            DispatchQueue.main.async {
                // textView.textStorage?.append(NSAttributedString(string: output, attributes: self?.normalMessageAttributes))
                self?.delegate?.shouldUpdateVideoOutView(output)
                // self?.scrollToBottom(textView)
                print(output)
            }
        }
        
        
        process.terminationHandler = { _ in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                switch status {
                case 0:
                    self.delegate?.shouldUpdateVideoOutView("\nSuccess converting \(fileURL.path).\n")
                    // self.scrollToBottom(textView)
                default:
                    self.delegate?.shouldUpdateVideoOutView("\nError converting \(fileURL), failed with status code \(status).\n")
                    // self.scrollToBottom(textView)
                }
            }
            completion(status == 0, status == 0 ? "Success converting \(fileURL)." : "Error converting \(fileURL), failed with status code \(status).")
        }

        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateVideoOutView("\(fileURL): Failed to start conversion process: \(error.localizedDescription)")
            }
            completion(false, "\n\(fileURL): Failed to start conversion process: \(error.localizedDescription)")
        }
            
    }
    
    // private func scrollToBottom(_ textView: NSTextView) {
    //     textView.scrollRangeToVisible(NSRange(location: textView.string.count, length: 0))
    // }

}

