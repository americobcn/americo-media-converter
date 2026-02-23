import Cocoa

protocol ConverterDelegate: AnyObject {
    func shouldUpdateOutView(_ text: String, _ attributes: [NSAttributedString.Key: Any])
    func conversionProgress(forRow row: Int, _ percent: Double)
    func showProgressBar(_ row: Int)
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
        ffmpegURL = Constants.checkBinary(binary: "ffmpeg")
        if ffmpegURL == nil {
            Constants.dropAlert(message: "ffmpeg is missing",
                                informative: "Install ffmpeg binary in Resources folder of the app.\nIf ffmpeg is located in /usr/local/bin/ffmpeg, copy the binary in the Resources folder of the app.")
            NSApplication.shared.terminate(nil)
        }
    }
    
    func convert(file: mediaFile,
                args: String,
                outPath: String,
                 row: Int,
                completion: @escaping (Bool, String?, Int32) -> Void) { 
        
        // Update UI with start message
        delegate?.shouldUpdateOutView("Start Converting\n", Constants.MessageAttribute.succesMessageAttributes)
        delegate?.showProgressBar(row)
        
        var duration = 0.0
        if let fileDuration = file.formatDescription["duration"] as? Double {
            duration = fileDuration
        }
                
        // Create and configure process
        let process = Process()
        process.executableURL = ffmpegURL
        let arguments = buildArguments(file: file, args: args, outPath: outPath)
        process.arguments = arguments
        
        // Setup pipes and handlers
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        let fileHandle = outputPipe.fileHandleForReading
        
        fileHandle.readabilityHandler = { [weak self] handle in
            self?.handleOutput(handle, duration, file: file, row: row)
        }
        
        process.terminationHandler = { [weak self] process in
            self?.handleProcessTermination(process, file: file, completion: completion)
        }
        
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
    
    private func buildArguments(file: mediaFile, args: String, outPath: String) -> [String] {
        var arguments: [String] = ["-hide_banner", "-progress", "pipe:1",
                                   "-nostats", "-i", file.mfURL.path]
        arguments.append(contentsOf: args.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        arguments.append(outPath)
        return arguments
    }
    
    
    private func handleOutput(_ fileHandle: FileHandle,  _ duration: Double, file: mediaFile, row: Int) {
        let data = fileHandle.availableData
        guard let output = String(data: data, encoding: .utf8) else { return }
        if output.contains("out_time_ms") {
            processProgressOutput(output, duration ,file: file, row: row)
        } else {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView(output, Constants.MessageAttribute.regularMessageAttributes)
            }
        }
    }
    
    
    private func processProgressOutput(_ output: String, _ duration: Double, file: mediaFile, row: Int) {
        let components = output.split(separator: "\n").filter { $0.contains("out_time_ms") }
        for component in components {
            let timeComponents = component.split(separator: "=")
            if timeComponents.count == 2,
               let micro = Double(timeComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                let seconds = micro / 1_000_000
                DispatchQueue.main.async { [weak self] in
                    self?.updateProgress(seconds, duration , file: file, output, row: row)
                }
            }
        }
    }
    
    
    private func updateProgress(_ seconds: Double, _ duration: Double, file: mediaFile, _ output: String, row: Int) {
        let progress = round(min((seconds / duration) * 100, 100) * 100) / 100.0
        delegate?.conversionProgress(forRow: row, progress)
        delegate?.shouldUpdateOutView(output, Constants.MessageAttribute.regularMessageAttributes)
    }
    
    
    private func handleProcessTermination(_ process: Process, file: mediaFile, completion: @escaping (Bool, String?, Int32) -> Void) {
        let status = process.terminationStatus
        
        DispatchQueue.main.async {
            if status == 0 {
                self.delegate?.shouldUpdateOutView("\nSuccess converting \(file.mfURL.lastPathComponent).\n",
                                                   Constants.MessageAttribute.succesMessageAttributes)
            } else {
                self.delegate?.shouldUpdateOutView("\nError converting \(file.mfURL.lastPathComponent), failed with status code \(status).\n",
                                                   Constants.MessageAttribute.errorMessageAttributes)                
            }
            completion(status == 0, nil, status)
        }
        runningProcesses.remove(process)
    }
    
    func cancelAllProcesses() {
        for process in runningProcesses {
            if process.isRunning {
                process.terminate()
            }
        }
        runningProcesses.removeAll()
    }
    
    deinit {
        cancelAllProcesses()
    }
}
