import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let text: String
    let kind: LogKind

    var displayText: String {
        var trimmed = text
        while trimmed.hasSuffix("\n") {
            trimmed.removeLast()
        }
        return trimmed
    }
}
