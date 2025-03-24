import Foundation

class VideoConverter {
    let ffmpegPath: String
    
    init(ffmpegPath: String = "/usr/local/bin/ffmpeg") {
        self.ffmpegPath = ffmpegPath
    }
    
    
    func convertVideo(inputPath: String, outputPath: String, format: String, completion: @escaping (Bool, String?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        
        let arguments = ["-i", inputPath, "-c:v", "libx264", "-preset", "medium", "-crf", "23", "-c:a", "aac", "-b:a", "192k", outputPath]
        process.arguments = arguments
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
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

