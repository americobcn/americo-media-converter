# AGENTS.md

Guidelines for agentic coding assistants working on Americo's Media Converter.

## Project Overview

Americo's Media Converter is a native macOS Swift application that provides a graphical frontend for `ffmpeg` and `ffprobe` command-line tools. It supports audio/video format conversion, batch processing, and media inspection.

## Build/Lint/Test Commands

### Building

```bash
# Build the project (debug)
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" -configuration Debug build

# Build the project (release)
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" -configuration Release build

# Build and open in Xcode
open "Americo's Media Converter.xcodeproj"
```

### Running Tests

```bash
# Run all tests (when available)
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" test

# Run a specific test file
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" -only-testing:AmericoMediaConverterTests/TestFileName test

# Run a specific test case
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" -only-testing:AmericoMediaConverterTests/TestFileName/testMethodName test
```

### Linting

```bash
# SwiftLint (if installed)
swiftlint

# SwiftFormat (if installed)
swiftformat --lint .
```

## Project Structure

```
Americo's Media Converter/
├── AppDelegate.swift              # Application delegate, window setup
├── Controllers/
│   ├── Constants.swift            # Global constants, supported formats, helper functions
│   ├── MediaController.swift      # FFprobe integration, format descriptions
│   ├── MVC.swift                  # Main view controller, UI logic
│   └── PreferenceManager.swift    # UserDefaults management, preferences UI
├── Converters/
│   └── Converter.swift            # FFmpeg process management, conversion logic
└── Views/
    ├── AC3Buttons.swift           # Custom button subclass
    └── CustomCellView.swift       # Custom table cell with progress indicator
```

## Code Style Guidelines

### Imports

```swift
import Cocoa
import Foundation
import AVFoundation
import CoreMedia
```

- Group imports alphabetically
- Cocoa first, then Foundation, then framework-specific imports
- No blank lines between import statements

### MARK Comments

Use MARK comments to organize code sections:

```swift
// MARK: - Section Name
// MARK: IBAction Methods
// MARK: TableView Delegate Methods
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `MediaController`, `PreferencesManager` |
| Structs | PascalCase | `mediaFile`, `Constants` |
| Enums | PascalCase | `VideoCodecs`, `AudioTypes` |
| Functions | camelCase | `convertAudio()`, `getMetadata(asset:)` |
| Variables | camelCase | `filesTableView`, `selectedVideoCodec` |
| Constants | camelCase | `playableFileExt`, `supportedFileExt` |
| Private enums | PascalCase | `Keys`, `PreferencesTextFieldTag` |

### Properties

```swift
@IBOutlet weak var filesTableView: NSTableView!
private var preferencesWindowController: PreferencesWindowController?
private(set) var selectedVideoCodec: VideoCodecs = .ProRes
static let shared = PreferencesManager()
```

- Use `@IBOutlet weak var` for Interface Builder outlets
- Use `private(set)` for read-only properties outside the class
- Use `static let shared` for singletons

### Enums

```swift
enum VideoCodecs: String, CaseIterable, Identifiable {
    case ProRes, DNxHD, H264
    
    var id: Self { return self }
    
    var codec: String {
        switch self {
        case .ProRes: return "prores_ks"
        case .DNxHD: return "dnxhd"
        case .H264: return "libx264"
        }
    }
}

private enum Keys {
    static let isNotificationsEnabled = "isNotificationsEnabled"
    static let defaultVideoDestination = "defaultVideoDestination"
}
```

- Conform to `CaseIterable` and `Identifiable` when appropriate
- Use private enums for constants like UserDefaults keys
- Use associated values and raw values where appropriate

### Switch Statements

```swift
switch selectedAudioType {
case .WAV:
    arguments = "-y -sample_fmt s\(audioBitsButton.title)..."
    break
    
case .AAC:
    arguments = "-y -vn -c:a \(Constants.aacCodec)..."
    break
    
default:
    break
}
```

- Always include a `default` case
- Use `break` explicitly at the end of each case
- Align `case` statements at the same indentation level

### Error Handling

```swift
enum FormatDescriptionError: Error {
    case unsupportedCodec(String)
    case missingRequiredField(String)
    case invalidData
    case creationFailed
}

func createFormatDescription(from stream: FFprobeStream) throws -> CMFormatDescription {
    guard let width = stream.width, let height = stream.height else {
        throw FormatDescriptionError.missingRequiredField("width or height")
    }
    // ...
}
```

- Define custom error enums conforming to `Error`
- Use `throw` and `try` for error propagation
- Use `guard` statements for early returns

### Guard Statements

```swift
guard let colIdentifier = tableColumn?.identifier else { return nil }
guard !selectedIndexes.isEmpty else { return }
```

- Use guard for early returns and unwrapping
- Keep guard conditions simple

### Async/Await

```swift
func isAVMediaType(url: URL) async -> (isPlayable: Bool, formats: [String: Any]) {
    let urlAsset = AVURLAsset(url: url)
    do {
        if try await urlAsset.load(.isPlayable) {
            // ...
        }
    } catch {
        print("Error loading AVURLAsset: \(error.localizedDescription)")
    }
}
```

- Use `async/await` for asynchronous operations
- Use `Task` when calling async from sync context

### Delegate Pattern

```swift
protocol ConverterDelegate: AnyObject {
    func shouldUpdateOutView(_ text: String, _ attributes: [NSAttributedString.Key: Any])
    func conversionProgress(forRow row: Int, _ percent: Double)
    func showProgressBar(_ row: Int)
}

class Converter {
    weak var delegate: ConverterDelegate?
}

class MVC: NSViewController, ConverterDelegate {
    func conversionProgress(forRow row: Int, _ percent: Double) {
        // Implementation
    }
}
```

- Use `AnyObject` protocol conformance for class-only delegates
- Use `weak var` for delegate references to avoid retain cycles

### Extensions

```swift
extension String {
    func toDouble() -> Double? {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "en_US_POSIX")
        return numberFormatter.number(from: self)?.doubleValue
    }
}

extension FourCharCode {
    func toString() -> String {
        // Implementation
    }
}
```

- Add utility methods via extensions
- Keep extensions for the same type together

### Comments

- Do NOT add comments unless explicitly requested
- Code should be self-documenting through clear naming

### Collections

```swift
var format: [String: Any] = [:]
let supportedFileExt: [AVMediaType: [String]] = [
    .video: ["mp4", "m4v", "mkv", ...],
    .audio: ["mp3", "aac", "wav", ...]
]
```

- Use type annotations for dictionaries with `Any` values
- Use trailing closure syntax for collection operations

### Process Management

```swift
// Use Task.detached for blocking Process calls to avoid blocking cooperative thread pool
private func runProcess(executableURL: URL, arguments: [String]) async throws -> Data {
    try await Task.detached {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }.value
}
```

- Use `Process` for external command execution
- Use `Pipe` for capturing output
- Wrap blocking `waitUntilExit()` in `Task.detached` to avoid blocking the cooperative thread pool

### Actors

```swift
actor MediaController {
    private let ffprobeURL: URL?
    
    func isAVMediaType(url: URL) async -> (isPlayable: Bool, formats: [String: Any]) {
        // Actor-isolated method - safe from data races
    }
    
    nonisolated func fourCharCode(from codecName: String) -> CMVideoCodecType? {
        // Pure synchronous function - can be called without await
    }
}
```

- Use `actor` for types with mutable state accessed from multiple contexts
- Use `nonisolated` for pure synchronous methods that don't need actor protection
- Call actor methods with `await` from outside the actor

## Dependencies

- **ffmpeg/ffprobe**: Bundled in app Resources folder, used for media conversion and probing
- **AVFoundation**: Native macOS media playback and inspection
- **CoreMedia**: Format description handling

## Notes
- Always use Context7 MCP when I need library/API documentation, code generation, 
  setup or configuration steps without me having to explicitly ask.
- The app bundles ffmpeg/ffprobe binaries in the Resources folder
- Supports ProRes, DNxHD, H.264 video codecs and WAV, MP3, AAC audio formats
- Uses UserDefaults for persistent preferences via `PreferencesManager.shared`
