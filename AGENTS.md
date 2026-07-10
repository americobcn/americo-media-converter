# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Native macOS Swift app providing a GUI frontend for bundled `ffmpeg`/`ffprobe` binaries (located in `Resources/`). Supports video/audio conversion, batch processing, and media inspection.

## Rules 

Read files first. Write complete solution. Test once. No over-engineering.

## Approach
- Think before acting. Read existing files before writing code.
- Be concise in output but thorough in reasoning.
- Prefer editing over rewriting whole files.
- Do not re-read files you have already read unless the file may have changed.
- Test your code before declaring done.
- No sycophantic openers or closing fluff.
- Keep solutions simple and direct.
- User instructions always override this file.

## Build Commands

```bash
# Debug build
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" -configuration Debug build

# Release build
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" -configuration Release build

# Run all tests
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" test

# Run a specific test
xcodebuild -project "Americo's Media Converter.xcodeproj" -scheme "americo-medio-converter" -only-testing:AmericoMediaConverterTests/TestFileName/testMethodName test

# Open in Xcode
open "Americo's Media Converter.xcodeproj"
```

## Architecture

```
Controllers/
  Constants.swift          # Global constants, supported format lists, helper extensions
  MediaController.swift    # actor — ffprobe integration, format/codec descriptions
  MVC.swift                # Main NSViewController — all UI logic and IBAction methods
  PreferenceManager.swift  # UserDefaults via PreferencesManager.shared singleton
Converters/
  Converter.swift          # FFmpeg Process management; reports progress via ConverterDelegate
Views/
  AC3Buttons.swift         # Custom NSButton subclass
  CustomCellView.swift     # Table cell with embedded progress indicator
```

**Data flow:** `MVC` (main view controller) holds the file queue and drives conversions. It creates `Converter` instances and conforms to `ConverterDelegate` to receive progress/output callbacks. `MediaController` (actor) runs `ffprobe` to inspect files before conversion. `PreferencesManager.shared` supplies user settings.

**Process execution:** All `Process`/`waitUntilExit()` calls are wrapped in `Task.detached` to avoid blocking the cooperative thread pool.

## Code Style

- **No comments** unless explicitly requested — use clear naming instead.
- Use `MARK: -` to organize code sections.
- Switch statements: always include `default`, use explicit `break`.
- Delegates: `protocol … : AnyObject`, `weak var delegate`.
- Singletons: `static let shared`.
- UserDefaults keys: private enum `Keys` with static string constants.
- Enums for codecs/formats conform to `CaseIterable` and `Identifiable`.
- Imports: alphabetical, Cocoa first, no blank lines between imports.

## Notes

- Always use Context7 MCP for library/API documentation without being asked.
- The scheme name is `americo-medio-converter` (note: "medio", not "media").
- `ffmpeg`/`ffprobe` binaries are bundled at `Resources/ffmpeg` and `Resources/ffprobe` — they must be present and executable.
- Supported video codecs: ProRes (`prores_ks`), DNxHD (`dnxhd`), H.264 (`libx264`).
- Supported audio formats: WAV, MP3, AAC.
