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

SwiftUI app (`App` lifecycle, no XIB). The libmpv player stays AppKit and is embedded with `NSViewRepresentable`.

```
AmericoMediaConverterApp.swift   # @main App: resizable Window scene (+ Media menu commands) + Settings scene
Models/
  MediaFile.swift                # Identifiable file row model; title/info computed once at init
  MediaOptions.swift             # Codec/format/profile/resolution/audio enums + ConversionTab
  LUFSTarget.swift               # Normalize loudness targets (title + LUFS value)
  FFmpegArguments.swift          # Pure ffmpeg argument builders for audio/video (unit-tested)
  MediaFormatDescriber.swift     # Format description strings, FourCC helpers
  LogEntry.swift / LogKind.swift # Log lines and their colors
ViewModels/
  ConverterViewModel.swift       # @Observable @MainActor, ConverterDelegate; state, dependent-picker resets (didSet), conversion flow
Views/                           # one type per file (synchronized folder)
  ContentView.swift              # Window layout (file list + buttons, player + tabs)
  FileListView.swift             # List with selection, reorder, drop; empty state is a drop target
  FileRowView.swift              # Row with icon, title, info, progress bar, failure icon
  ConversionTabsView.swift       # In-panel tab bar + AudioTabView / VideoTabView / NormalizeTabView
  ConversionTabBar.swift         # Icon + title tab buttons (Audio / Video / Normalize)
  LabeledControl.swift           # Title-above-control layout used by the tabs
  LogView.swift                  # Black auto-scrolling colored log (reads its own tab's log)
  AC3ButtonStyle.swift / AC3ButtonBody.swift  # Cancel / Convert button style
  PlayerView.swift               # NSViewRepresentable around the VM-owned MPVPlayerView
  PlaybackCommands.swift         # Media menu: Delete removes selection (Space play/pause is a key monitor in the VM)
  FocusedValues+Converter.swift  # Focused scene value that enables the Media menu
  PreferencesView.swift          # Settings: GeneralPreferencesView / NotificationsPreferencesView
  MPVPlayerView.swift            # AppKit libmpv/OpenGL player
Controllers/
  Constants.swift                # Global constants, supported format lists, binary/encoder checks
  MediaController.swift          # actor — ffprobe integration, format/codec descriptions
  PreferenceManager.swift        # UserDefaults via PreferencesManager.shared singleton
Converters/
  Converter.swift                # FFmpeg Process management; reports progress via ConverterDelegate
AmericoMediaConverterTests/      # Swift Testing unit tests (hosted in the app), Debug test configuration
```

**Data flow:** `ConverterViewModel` (injected with `.environment`) holds the file queue and drives conversions. It owns the `Converter` and conforms to the `@MainActor` `ConverterDelegate` to receive log/progress callbacks. `MediaController` (actor) runs `ffprobe` to inspect files before they are added. `PreferencesManager.shared` supplies user settings.

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
- Update CLAUDE.md and README.me after a new feature is implemented or app update.
