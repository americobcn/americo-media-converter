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
    
    func normalize(file: mediaFile,
                   targetLUFS: Int,
                   scriptURL: URL,
                   resourcesURL: URL,
                   row: Int,
                   completion: @escaping (Bool, String?, Int32) -> Void) {
        delegate?.showProgressBar(row)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, "-i", "\(targetLUFS).0", file.mfURL.path]
        process.environment = ["PATH": "\(resourcesURL.path):/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        let fileHandle = outputPipe.fileHandleForReading

        var outputBuffer = ""
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            outputBuffer += chunk
            let lines = outputBuffer.components(separatedBy: "\n")
            outputBuffer = lines.last ?? ""
            for line in lines.dropLast() {
                guard !line.isEmpty else { continue }
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.shouldUpdateOutView(line.strippingANSI + "\n", Constants.MessageAttribute.regularMessageAttributes)
                    if line.contains("Pass 1/2") { self?.delegate?.conversionProgress(forRow: row, 30.0) }
                    else if line.contains("Pass 2/2") { self?.delegate?.conversionProgress(forRow: row, 70.0) }
                    else if line.contains("[OK]") { self?.delegate?.conversionProgress(forRow: row, 100.0) }
                }
            }
        }

        process.terminationHandler = { [weak self] process in
            // Drain any remaining pipe data and flush the buffer
            fileHandle.readabilityHandler = nil
            let finalData = fileHandle.readDataToEndOfFile()
            if let finalChunk = String(data: finalData, encoding: .utf8), !finalChunk.isEmpty {
                outputBuffer += finalChunk
            }
            let remaining = outputBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.shouldUpdateOutView(remaining.strippingANSI + "\n", Constants.MessageAttribute.regularMessageAttributes)
                    if remaining.contains("Pass 1/2") { self?.delegate?.conversionProgress(forRow: row, 30.0) }
                    else if remaining.contains("Pass 2/2") { self?.delegate?.conversionProgress(forRow: row, 70.0) }
                    else if remaining.contains("[OK]") { self?.delegate?.conversionProgress(forRow: row, 100.0) }
                }
            }
            let status = process.terminationStatus
            DispatchQueue.main.async {
                if status == 0 {
                    self?.delegate?.shouldUpdateOutView(
                        "\nNormalization of \(file.mfURL.lastPathComponent) complete.\n",
                        Constants.MessageAttribute.succesMessageAttributes)
                } else {
                    self?.delegate?.shouldUpdateOutView(
                        "\nNormalization of \(file.mfURL.lastPathComponent) failed with status \(status).\n",
                        Constants.MessageAttribute.errorMessageAttributes)
                }
                completion(status == 0, nil, status)
            }
            self?.runningProcesses.remove(process)
        }

        runningProcesses.insert(process)

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView(
                    "\(file.mfURL.lastPathComponent): Failed to start normalization: \(error.localizedDescription)\n",
                    Constants.MessageAttribute.errorMessageAttributes)
                completion(false, error.localizedDescription, -1)
            }
        }
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

private extension String {
    var strippingANSI: String {
        replacingOccurrences(of: #"\x1B\[[0-9;]*m"#, with: "", options: .regularExpression)
    }
}
