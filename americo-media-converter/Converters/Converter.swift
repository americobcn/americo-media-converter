import Cocoa

protocol ConverterDelegate: AnyObject {
    func shouldUpdateOutView(_ text: String, _ attributes: [NSAttributedString.Key: Any])
}


class Converter {
    weak var delegate: ConverterDelegate?
    private var ffmpegURL: URL?
    private var runningProcesses: Set<Process> = []
    
    init(delegate: ConverterDelegate) {
        self.delegate = delegate
        setup()
    }
    
    private func setup() {
        self.ffmpegURL = nil
        self.ffmpegURL = Constants.checkBinary(binary: "ffmpeg")
        if self.ffmpegURL == nil {
            Constants.dropAlert(message: "ffmpeg is missing",
                                  informative: "Install ffmpeg binary in Resources folder of the app.\nIf ffmpeg is located in /usr/local/bin/ffmpeg, copy the binary in the Resources folder of the app.")
            NSApplication.shared.terminate(nil)
        }
    }
    
    func convert(fileURL: URL,
                args: String,
                outPath: String,
                completion: @escaping (Bool, String?, Int32) -> Void) {
        
        // Validate inputs
        guard let ffmpegURL = self.ffmpegURL else {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView("FFmpeg not found. Cannot start conversion.\n",
                                                  Constants.MessageAttribute.errorMessageAttributes)
            }
            completion(false, "FFmpeg not found", -1)
            return
        }
        
        // Update UI with start message
        delegate?.shouldUpdateOutView("Start Converting\n", Constants.MessageAttribute.succesMessageAttributes)
        
        // Create process
        let process = Process()
        process.executableURL = ffmpegURL
        
        // Build arguments
        var arguments = ["-i", fileURL.path]
        arguments.append(contentsOf: args.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        arguments.append(outPath)
        
        process.arguments = arguments
        print("arguments: \(arguments)")
        
        // Setup pipes for output
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // Setup readability handler
        let fileHandle = outputPipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.delegate?.shouldUpdateOutView(output, Constants.MessageAttribute.regularMessageAttributes)
//                    print(output)
                }
            }
        }
        
        // Setup termination handler
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                switch status {
                case 0:
                    self?.delegate?.shouldUpdateOutView("\nSuccess converting \(fileURL.lastPathComponent).\n",
                                                       Constants.MessageAttribute.succesMessageAttributes)
                default:
                    self?.delegate?.shouldUpdateOutView("\nError converting \(fileURL.lastPathComponent), failed with status code \(status).\n",
                                                       Constants.MessageAttribute.errorMessageAttributes)
                }
                completion(status == 0, nil, status)
            }
        }
        
        // Track process for cleanup
        runningProcesses.insert(process)
        
        // Run process
        do {
            print("Starting process: \(ffmpegURL.path) with args: \(arguments)")
            try process.run()
            process.waitUntilExit()
            
            // Remove from tracking after completion
            self.runningProcesses.remove(process)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView("\(fileURL.lastPathComponent): Failed to start conversion process: \(error.localizedDescription)\n",
                                                  Constants.MessageAttribute.errorMessageAttributes)
                completion(false, error.localizedDescription, -1)
            }
        }
    }


    // Cancel all running processes
    func cancelAllProcesses() {
        for process in runningProcesses {
            if process.isRunning {
                process.terminate()
            }
        }
        runningProcesses.removeAll()
    }
    
    /// Clean up resources
    deinit {
        cancelAllProcesses()
    }
}


/*
    func checkFFmpeg() -> Bool {
        // First, try to find ffmpeg in the app bundle
        if let url = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) {
            self.ffmpegURL = url
            return true
        }
        
        // If not found in bundle, search system paths
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["ffmpeg"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                self.ffmpegURL = URL(fileURLWithPath: path)
                return true
            }
        } catch {
            print("Error checking for ffmpeg: \(error)")
        }
        
        return false
    }
*/
