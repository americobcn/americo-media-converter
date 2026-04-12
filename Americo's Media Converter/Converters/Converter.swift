import Cocoa

protocol ConverterDelegate: AnyObject {
    func shouldUpdateOutView(_ text: String, _ attributes: [NSAttributedString.Key: Any])
    func conversionProgress(forRow row: Int, _ percent: Double)
    func showProgressBar(_ row: Int)
}

class Converter {
    weak var delegate: ConverterDelegate?
    private var ffmpegURL: URL?
    private var ffprobeURL: URL?
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
        ffprobeURL = Constants.checkBinary(binary: "ffprobe")
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

    // MARK: - Normalize

    func normalize(file: mediaFile,
                   targetLUFS: Int,
                   row: Int,
                   completion: @escaping (Bool, String?, Int32) -> Void) {
        delegate?.showProgressBar(row)
        delegate?.shouldUpdateOutView("Start Normalizing\n", Constants.MessageAttribute.succesMessageAttributes)

        guard let ffmpegURL = ffmpegURL, let ffprobeURL = ffprobeURL else {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView(
                    "Missing ffmpeg or ffprobe binary.\n",
                    Constants.MessageAttribute.errorMessageAttributes)
                completion(false, nil, -1)
            }
            return
        }

        Task.detached { [weak self] in
            // Step A: probe input for codec name and sample rate
            let (inputCodec, sampleRate) = Self.probeAudioStream(url: file.mfURL, ffprobeURL: ffprobeURL)
            guard let inputCodec, let sampleRate, let outCodec = Self.outputCodec(for: inputCodec) else {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.shouldUpdateOutView(
                        "Failed to probe \(file.mfURL.lastPathComponent).\n",
                        Constants.MessageAttribute.errorMessageAttributes)
                    completion(false, nil, -1)
                }
                return
            }

            // Step B: Pass 1 — loudness analysis
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.shouldUpdateOutView(
                    "Pass 1/2 — Analysing loudness...\n",
                    Constants.MessageAttribute.regularMessageAttributes)
                self?.delegate?.conversionProgress(forRow: row, 30.0)
            }

            let pass1Args = ["-hide_banner", "-nostdin", "-v", "info",
                             "-i", file.mfURL.path,
                             "-af", "loudnorm=I=\(targetLUFS).0:TP=-1.0:LRA=18.0:print_format=json",
                             "-vn", "-sn", "-f", "null", "/dev/null"]
            let (pass1Output, pass1Status) = Self.runNormalizeProcess(executableURL: ffmpegURL, arguments: pass1Args)

            guard pass1Status == 0 else {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.shouldUpdateOutView(
                        "Pass 1 failed with status \(pass1Status).\n",
                        Constants.MessageAttribute.errorMessageAttributes)
                    completion(false, nil, pass1Status)
                }
                return
            }

            // Step C: parse JSON from pass 1 output
            guard let jsonString = Self.extractLoudnormJSON(from: pass1Output),
                  let m = Self.parseLoudnormJSON(jsonString) else {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.shouldUpdateOutView(
                        "Failed to parse loudnorm measurements.\n",
                        Constants.MessageAttribute.errorMessageAttributes)
                    completion(false, nil, -1)
                }
                return
            }

            // Step D: Pass 2 — apply normalization
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.shouldUpdateOutView(
                    "Pass 2/2 — Applying normalization...\n",
                    Constants.MessageAttribute.regularMessageAttributes)
                self?.delegate?.conversionProgress(forRow: row, 70.0)
            }

            let outputURL = Self.normalizeOutputURL(for: file.mfURL, targetLUFS: targetLUFS)
            let filter = "loudnorm=I=\(targetLUFS).0:TP=-1.0:LRA=18.0" +
                         ":measured_I=\(m.inputI):measured_LRA=\(m.inputLRA)" +
                         ":measured_TP=\(m.inputTP):measured_thresh=\(m.inputThresh)" +
                         ":offset=\(m.targetOffset):linear=true"
            let pass2Args = ["-hide_banner", "-nostdin", "-y",
                             "-i", file.mfURL.path,
                             "-map_metadata", "0",
                             "-map", "0:a:0",
                             "-af", filter,
                             "-ar", sampleRate,
                             "-c:a", outCodec,
                             outputURL.path]
            let (_, pass2Status) = Self.runNormalizeProcess(executableURL: ffmpegURL, arguments: pass2Args)

            guard pass2Status == 0 else {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.shouldUpdateOutView(
                        "\nNormalization of \(file.mfURL.lastPathComponent) failed with status \(pass2Status).\n",
                        Constants.MessageAttribute.errorMessageAttributes)
                    completion(false, nil, pass2Status)
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.shouldUpdateOutView(
                    "\nNormalization of \(file.mfURL.lastPathComponent) complete.\n",
                    Constants.MessageAttribute.succesMessageAttributes)
                self?.delegate?.conversionProgress(forRow: row, 90.0)
                self?.delegate?.shouldUpdateOutView(
                    "Pass 3/3 — Verifying output...\n",
                    Constants.MessageAttribute.regularMessageAttributes)
            }

            let verification = Self.verifyNormalizedFile(url: outputURL, ffmpegURL: ffmpegURL, ffprobeURL: ffprobeURL)

            DispatchQueue.main.async { [weak self] in
                if let v = verification {
                    let bitDepthStr = (v.bitDepth == "N/A" || v.bitDepth == "0") ? "N/A" : "\(v.bitDepth) bit"
                    let sampleRateStr = v.sampleRate == "N/A" ? "N/A" : "\(v.sampleRate) Hz"
                    let report = "  File:                \(outputURL.lastPathComponent)\n" +
                                 "  Bit depth:           \(bitDepthStr)\n" +
                                 "  Sample rate:         \(sampleRateStr)\n" +
                                 "  Integrated loudness: \(v.integratedLoudness)\n" +
                                 "  Loudness range:      \(v.loudnessRange)\n" +
                                 "  True peak:           \(v.truePeak)\n"
                    self?.delegate?.shouldUpdateOutView(report, Constants.MessageAttribute.regularMessageAttributes)
                } else {
                    self?.delegate?.shouldUpdateOutView(
                        "Verification failed — could not read output file stats.\n",
                        Constants.MessageAttribute.errorMessageAttributes)
                }
                self?.delegate?.conversionProgress(forRow: row, 100.0)
                completion(true, nil, 0)
            }
        }
    }

    // MARK: - Normalize Helpers

    private static func runNormalizeProcess(executableURL: URL, arguments: [String]) -> (String, Int32) {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        var output = ""
        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let chunk = String(data: handle.availableData, encoding: .utf8) {
                output += chunk
            }
        }
        do {
            try process.run()
        } catch {
            return ("", -1)
        }
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
        if let chunk = String(data: remaining, encoding: .utf8) {
            output += chunk
        }
        return (output, process.terminationStatus)
    }

    private static func probeAudioStream(url: URL, ffprobeURL: URL) -> (String?, String?) {
        let args = ["-v", "error", "-select_streams", "a:0",
                    "-show_entries", "stream=codec_name,sample_rate",
                    "-of", "csv=p=0", url.path]
        let (output, status) = runNormalizeProcess(executableURL: ffprobeURL, arguments: args)
        guard status == 0 else { return (nil, nil) }
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ",")
        guard parts.count >= 2 else { return (nil, nil) }
        return (parts[0], parts[1])
    }

    private static func outputCodec(for inputCodec: String) -> String? {
        switch inputCodec {
        case "pcm_u8", "pcm_s16le", "pcm_s16be", "pcm_s24le", "pcm_s24be",
             "pcm_s32le", "pcm_s32be", "pcm_f32le", "pcm_f32be",
             "pcm_f64le", "pcm_f64be":
            return inputCodec
        case "flac": return "flac"
        case "alac": return "alac"
        case "mp3": return "libmp3lame"
        case "aac": return "aac"
        case "opus": return "libopus"
        case "vorbis": return "libvorbis"
        case "ac3": return "ac3"
        case "eac3": return "eac3"
        default: return nil
        }
    }

    private static func extractLoudnormJSON(from output: String) -> String? {
        let lines = output.components(separatedBy: "\n")
        var inBlock = false
        var jsonLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "{" { inBlock = true }
            if inBlock { jsonLines.append(line) }
            if inBlock && trimmed == "}" { break }
        }
        let jsonString = jsonLines.joined(separator: "\n")
        return jsonString.isEmpty ? nil : jsonString
    }

    private struct LoudnormMeasurements {
        let inputI: String
        let inputLRA: String
        let inputTP: String
        let inputThresh: String
        let targetOffset: String
    }

    private static func parseLoudnormJSON(_ jsonString: String) -> LoudnormMeasurements? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let inputI = dict["input_i"],
              let inputLRA = dict["input_lra"],
              let inputTP = dict["input_tp"],
              let inputThresh = dict["input_thresh"],
              let targetOffset = dict["target_offset"]
        else { return nil }
        return LoudnormMeasurements(inputI: inputI, inputLRA: inputLRA,
                                    inputTP: inputTP, inputThresh: inputThresh,
                                    targetOffset: targetOffset)
    }

    private static func normalizeOutputURL(for input: URL, targetLUFS: Int) -> URL {
        let suffix = targetLUFS == -23 ? "_EBU_R128(\(targetLUFS)LUFS)" : "_(\(targetLUFS)LUFS)"
        let dir = input.deletingLastPathComponent()
        let name = input.deletingPathExtension().lastPathComponent
        let ext = input.pathExtension
        return dir.appendingPathComponent(name + suffix + (ext.isEmpty ? "" : "." + ext))
    }

    private struct VerificationResult {
        let bitDepth: String
        let sampleRate: String
        let integratedLoudness: String
        let loudnessRange: String
        let truePeak: String
    }

    private static func verifyNormalizedFile(url: URL, ffmpegURL: URL, ffprobeURL: URL) -> VerificationResult? {
        let probeArgs = ["-v", "error", "-select_streams", "a:0",
                         "-show_entries", "stream=sample_rate,bits_per_raw_sample",
                         "-of", "csv=p=0", url.path]
        let (probeOutput, probeStatus) = runNormalizeProcess(executableURL: ffprobeURL, arguments: probeArgs)
        guard probeStatus == 0 else { return nil }
        let parts = probeOutput.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ",")
        let sampleRate = parts.count >= 1 && !parts[0].isEmpty ? parts[0] : "N/A"
        let bitDepth = parts.count >= 2 && !parts[1].isEmpty ? parts[1] : "N/A"

        let ebur128Args = ["-hide_banner", "-nostdin", "-v", "info",
                           "-i", url.path,
                           "-af", "ebur128=peak=true",
                           "-f", "null", "/dev/null"]
        let (ebur128Output, ebur128Status) = runNormalizeProcess(executableURL: ffmpegURL, arguments: ebur128Args)
        guard ebur128Status == 0 else { return nil }

        let integratedLoudness = parseEBUR128Value(from: ebur128Output, key: "I:") ?? "N/A"
        let loudnessRange = parseEBUR128Value(from: ebur128Output, key: "LRA:") ?? "N/A"
        let truePeak = parseEBUR128Value(from: ebur128Output, key: "Peak:") ?? "N/A"

        return VerificationResult(bitDepth: bitDepth, sampleRate: sampleRate,
                                  integratedLoudness: integratedLoudness,
                                  loudnessRange: loudnessRange, truePeak: truePeak)
    }

    private static func parseEBUR128Value(from output: String, key: String) -> String? {
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(key) {
                return String(trimmed.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - Cancel

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
