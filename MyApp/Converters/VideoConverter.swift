import Foundation

class VideoConverter {
    let ffmpegPath: String
    
    init(ffmpegPath: String = "/usr/local/bin/ffmpeg") {
        self.ffmpegPath = ffmpegPath
    }
    
    
    func convertVideo(fileURL: URL,
                      args: String,
                      container: String,
                      completion: @escaping (Bool, String?) -> Void
    ) {
        print("Started Converting Video")
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
                print(output)
            }
        }
        
        
        process.terminationHandler = { _ in
            let status = process.terminationStatus
            completion(status == 0, status == 0 ? nil : "Conversion failed with status code \(status)")
        }
        
        do {
            try process.run()
        } catch {
            completion(false, "Failed to start ffmpeg process: \(error.localizedDescription)")
        }
    }
}

// Example Usage:
/*
let converter = VideoConverter()
converter.convertVideo(inputPath: "/path/to/input.mp4", outputPath: "/path/to/output.mov", format: "mov") { success, error in
    if success {
        print("Conversion successful!")
    } else {
        print("Error: \(error ?? "Unknown error")")
    }
}
*/

