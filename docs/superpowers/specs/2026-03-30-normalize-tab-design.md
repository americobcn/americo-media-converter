# Normalize Tab — Design Spec

**Date:** 2026-03-30
**Status:** Approved

## Context

The app exposes ffmpeg audio/video conversion via Audio and Video tabs. Users who work with audio for broadcast, streaming, or podcast delivery need EBU R128 loudness normalization — a two-pass process that measures then corrects integrated loudness to a target LUFS. A standalone bash script (`normalize_r128.sh`) already implements this via ffmpeg's `loudnorm` filter. This feature adds a third **Normalize** tab to the converter tab view, wiring the existing script into the app's batch queue and progress UI.

## Architecture

Five files change; nothing else is touched.

| File | Change |
|------|--------|
| `Resources/normalize_r128.sh` | New — bundled script (copied from dev scripts) |
| `Resources/jq` | New — bundled binary (required by the script) |
| `MainMenu.xib` | New NSTabViewItem "Normalize" added to `converterTabView` |
| `Controllers/MVC.swift` | 3 new IBOutlets, new `convertNormalize()`, branch in `startConversion` |
| `Converters/Converter.swift` | New `normalize()` method |

`ConverterDelegate`, `Constants`, `MediaController`, `PreferenceManager`, `CustomCellView`, and `AC3Buttons` are unchanged.

## UI — Normalize Tab (MainMenu.xib)

New `NSTabViewItem` with label `"Normalize"` added alongside Audio and Video in `converterTabView`.

**Controls inside the tab:**

- `NSSegmentedControl` (`normalizeLUFSControl`) — 4 segments, default selected = 0
  - Segment 0: `−23 LUFS` (EBU R128) — default
  - Segment 1: `−16 LUFS`
  - Segment 2: `−14 LUFS`
  - Segment 3: `−12 LUFS`
- `NSScrollView` + `NSTextView` (`normalizeOutTextView`) — output log, same styling as `audioOutTextView`

**New IBOutlets in MVC.swift:**

```swift
@IBOutlet weak var normalizeTabView: NSTabViewItem!
@IBOutlet weak var normalizeLUFSControl: NSSegmentedControl!
@IBOutlet weak var normalizeOutTextView: NSTextView!
```

## Script Invocation

The script and `jq` are bundled in `Resources/`. The normalize method resolves both from `Bundle.main.resourceURL`.

```
executable: /bin/bash
arguments:  [scriptURL.path, "-i", "\(targetLUFS).0", file.mfURL.path]
environment: PATH = <resourcesURL.path>:/usr/bin:/bin:/usr/local/bin
```

`jq` is found via the prepended `PATH`. Output goes to the same directory as the input file; the script appends a suffix (`_EBU_R128(-23LUFS)` for −23, `_(-14LUFS)` for other targets). No output path is passed — the script owns naming.

## Converter.swift — normalize()

```swift
func normalize(file: mediaFile, targetLUFS: Int, scriptURL: URL, resourcesURL: URL,
               row: Int, completion: @escaping (Bool, String?, Int32) -> Void)
```

- Runs via `Task.detached` (wraps blocking `waitUntilExit()`, consistent with existing process management pattern)
- Pipes combined stdout+stderr
- `readabilityHandler` buffers incoming data into a string accumulator, flushes on newlines, and parses progress markers per line:
  - `"Pass 1/2"` → `conversionProgress(forRow: row, 0.3)`
  - `"Pass 2/2"` → `conversionProgress(forRow: row, 0.7)`
  - `"[OK]"` → `conversionProgress(forRow: row, 1.0)`
- Each line forwarded to `shouldUpdateOutView(_:_:)` with `regularMessageAttributes`
- `terminationStatus == 0` → success; anything else → `progressBarError(idx)` in MVC

## MVC.swift — convertNormalize()

```swift
func convertNormalize() {
    guard let resourcesURL = Bundle.main.resourceURL else { return }
    let scriptURL = resourcesURL.appendingPathComponent("normalize_r128.sh")
    let lufsValues = [-23, -16, -14, -12]
    let targetLUFS = lufsValues[normalizeLUFSControl.selectedSegment]

    normalizeOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))

    for (idx, file) in files.enumerated() {
        cv.normalize(file: file, targetLUFS: targetLUFS, scriptURL: scriptURL,
                     resourcesURL: resourcesURL, row: idx) { success, _, _ in
            if !success { self.progressBarError(idx) }
        }
    }
}
```

`startConversion()` gains a `case "Normalize"` branch that calls `resetAllProgressBar()` then `convertNormalize()`.

## Verification

1. Build — confirms XIB outlets wire without errors
2. Drop a WAV, select −14 LUFS, click Convert → progress bar: 30% → 70% → 100%; output file appears in same folder with suffix `_(-14LUFS)`
3. Repeat with MP3 → script logs lossy-codec warning in output view
4. Drop a non-audio file → script exits 1 → row shows error state
5. Select −23 LUFS → output suffix is `_EBU_R128(-23LUFS)`
