# Americo's Media Converter

Americo's Media Converter is a native macOS graphical frontend for the `ffmpeg` command-line tools. It simplifies common audio and video conversion, transcoding, and inspection tasks by wrapping `ffmpeg`/`ffprobe` in a user-friendly interface.

## Key Features

- Format conversion: Convert between common audio/video formats (MP4, MKV, MOV, MP3, AAC, FLAC).
- Batch processing: Queue multiple files and run conversions automatically.
- Metadata & probing: Inspect media streams, codecs, and bitrates via `ffprobe`.

## Architecture

This project is a native Swift macOS app that invokes bundled `ffmpeg` and `ffprobe` binaries from the app `Resources` folder. The app parses CLI output to display progress, errors, and file metadata, and provides a GUI for custom arguments.

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

## Contributing

Contributions and suggestions are welcome. Please open issues or pull requests in the repository.
