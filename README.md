# Americo's Media Converter

Americo's Media Converter is a native macOS graphical frontend for the `ffmpeg` command-line tools. It simplifies common audio and video conversion, transcoding, and inspection tasks by wrapping `ffmpeg`/`ffprobe` in a user-friendly interface.

## Key Features

- Format conversion: Convert between common audio/video formats (MP4, MKV, MOV, MP3, AAC, FLAC).
- Batch processing: Queue multiple files and run conversions automatically.
- Metadata & probing: Inspect media streams, codecs, and bitrates via `ffprobe`.

## Architecture

This project is a native Swift macOS app that invokes bundled `ffmpeg` and `ffprobe` binaries from the app `Resources` folder. The app parses CLI output to display progress, errors, and file metadata, and provides a GUI for custom arguments.

The UI is built with SwiftUI (`App` lifecycle, no XIB). The libmpv-based player stays AppKit (`MPVPlayerView`) and is embedded through `NSViewRepresentable`.

- `AmericoMediaConverterApp.swift`: `@main` app with a single resizable `Window` scene, a Media menu (Delete removes selected files) and a `Settings` scene (Cmd+,). Space toggles play/pause of the selected file anywhere in the main window.
- `ViewModels/ConverterViewModel.swift`: `@Observable` view model holding the file queue, selection, tab settings and logs; builds the `ffmpeg` arguments and drives `Converter`.
- `Models/`: `MediaFile`, `LogEntry`/`LogKind`, `LUFSTarget`, conversion option enums, `FFmpegArguments` (pure argument builders) and the media format describer.
- `Views/`: one type per file — `ContentView`, `FileListView`, `FileRowView`, `ConversionTabsView` with `AudioTabView` / `VideoTabView` / `NormalizeTabView`, `LogView`, `PlayerView`, `PlaybackCommands`, `AC3ButtonStyle`, `PreferencesView`.
- `Controllers/`: `MediaController` (ffprobe), `PreferencesManager` (UserDefaults) and shared `Constants`.
- `Converters/Converter.swift`: runs `ffmpeg` processes and reports progress through `ConverterDelegate`.
- `AmericoMediaConverterTests/`: Swift Testing unit tests for argument building and view-model behavior (`xcodebuild ... test`).

## Why this app

`ffmpeg` is powerful but command-driven; this app makes those capabilities accessible to users who prefer a graphical interface while preserving the ability to use custom `ffmpeg` flags when needed.

## Use Cases

- Quick format change: Convert a `.mov` to `.mp4` for web playback.
- Extract audio: Save the audio track of a video as `.mp3` or `.wav`.
- Batch transcode: Convert a folder of videos to a single format with one action.
- Prepare for devices: Apply device-optimized presets to ensure compatibility.
- Inspect media: Use `ffprobe` output to review codecs, bitrates, and stream layout.
- Accessible GUI for novices: Drag-and-drop, clear presets, and progress indicators for non-technical users.

## Quick Start

1. Open the Xcode project `Americo's Media Converter.xcodeproj` and build the app.
2. The app bundles `ffmpeg`/`ffprobe` under `Resources`; ensure those binaries are present and executable.
3. Launch the app, add files (or folders) to the queue, choose a preset or custom options, and run conversions.

