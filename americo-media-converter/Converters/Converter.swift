import Cocoa

protocol ConverterDelegate: AnyObject {
    func shouldUpdateOutView(_ text: String, _ attributes: [NSAttributedString.Key: Any])
    func conversionProgress(_ seconds: Double)
}


class Converter {
    weak var delegate: ConverterDelegate?
    private var ffmpegURL: URL?
    private var runningProcesses: Set<Process> = []
    private var duration: Double!
    
    init(delegate: ConverterDelegate) {
        self.delegate = delegate
        self.duration = 0.1
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
    
    
    
    //func convert(fileURL: URL,
    func convert(file: mediaFile,
                args: String,
                outPath: String,
                completion: @escaping (Bool, String?, Int32) -> Void) {
        
        // Update UI with start message
        delegate?.shouldUpdateOutView("Start Converting\n", Constants.MessageAttribute.succesMessageAttributes)
        // print("Duration: \(file.formatDescription["duration"]), type: \(type(of:file.formatDescription["duration"]))")
        if let doubleValue = file.formatDescription["duration"] as? Double {
            self.duration = doubleValue
        }
        // print(self.duration!)
        // Create process
        let process = Process()
        process.executableURL = ffmpegURL
        
        // Build arguments
        var arguments = ["-hide_banner", "-progress", "pipe:1",
                         "-nostats", "-i", file.mfURL.path]
        arguments.append(contentsOf: args.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        arguments.append(outPath)
        
        process.arguments = arguments
        print(arguments.joined(separator: " "))
        
        
        // Setup pipes for output
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // Setup readability handler
        let fileHandle = outputPipe.fileHandleForReading
        // Progress handler
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                // Parse ffmpeg progress (out_time_ms)
                if output.contains("out_time_ms") {
                    let components = output.components(separatedBy: "\n")
                    for c in components {
                        if c.contains("out_time_ms") {
                            let time = c.components(separatedBy: "=")
                            if time.count == 2,
                               let micro = Double(time[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                               let seconds = micro / 1_000_000
                                DispatchQueue.main.async {
                                    self?.delegate?.conversionProgress(min((seconds / self!.duration ) * 100, 100)) // min((seconds / self.duration ) * 100, 100)
                               }
                           }
                        }
                    }
                                            
                }                
                                    
                DispatchQueue.main.async {
                    self?.delegate?.shouldUpdateOutView(
                        output,
                        Constants.MessageAttribute.regularMessageAttributes
                    )
                }
            }
        }

        
    
        // Setup termination handler
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                switch status {
                case 0:
                    self?.delegate?.shouldUpdateOutView("\nSuccess converting \(file.mfURL.lastPathComponent).\n",
                                                       Constants.MessageAttribute.succesMessageAttributes)
                default:
                    self?.delegate?.shouldUpdateOutView("\nError converting \(file.mfURL.lastPathComponent), failed with status code \(status).\n",
                                                       Constants.MessageAttribute.errorMessageAttributes)
                }
                completion(status == 0, nil, status)
            }
            
            // Remove from tracking after completion
            self?.runningProcesses.remove(process)
        }
        
        // Track process for cleanup
        runningProcesses.insert(process)
                
        do {
            try process.run()
            
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView("\(file.mfURL.lastPathComponent): Failed to start conversion process: \(error.localizedDescription)\n",
                                                  Constants.MessageAttribute.errorMessageAttributes)
                completion(false, error.localizedDescription, -1)
            }
        }
    }


    // Cancel all running processes
    func cancelAllProcesses() {
        for process in runningProcesses {
            if process.isRunning {
                process.interrupt()
                process.terminate()
            }
        }
        runningProcesses.removeAll()
    }
        
    // Clean up resources
    deinit {
        cancelAllProcesses()
    }
    
}
