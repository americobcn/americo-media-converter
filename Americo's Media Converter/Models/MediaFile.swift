import Foundation

struct MediaFile: Identifiable, @unchecked Sendable {
    let id = UUID()
    let mfURL: URL
    let formatDescription: [String: Any]
    let title: String
    let info: String
    var progress: Double = 0.0
    var isProgressVisible = false
    var hasError = false

    var hasVideo: Bool {
        formatDescription.keys.contains("videoDesc")
    }

    init(mfURL: URL, formatDescription: [String: Any] = [:]) {
        self.mfURL = mfURL
        self.formatDescription = formatDescription
        self.title = "\(mfURL.lastPathComponent) | \(MediaFormatDescriber.formatSecondsTime(formatDescription["duration"] as? Double ?? 0.0))"
        self.info = MediaFormatDescriber.getFormatDescription(formatDescription)
    }
}
