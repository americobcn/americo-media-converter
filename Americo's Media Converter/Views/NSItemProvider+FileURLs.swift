import Foundation

extension Array where Element == NSItemProvider {
    func loadFileURLs() async -> [URL] {
        var urls: [URL] = []
        for provider in self {
            let url: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    continuation.resume(returning: url)
                }
            }
            if let url = url {
                urls.append(url)
            }
        }
        return urls
    }
}
