# Normalize Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third "Normalize" tab to the converter that runs the bundled EBU R128 two-pass loudness normalization script on queued files.

**Architecture:** Extend `Converter` with a `normalize()` method mirroring the existing `convert()` pattern (terminationHandler + readabilityHandler + runningProcesses). MVC gains three outlets and a `convertNormalize()` method wired into the `startConversion` switch. The script and `jq` binary live in `Resources/` alongside `ffmpeg`/`ffprobe`; the `PBXFileSystemSynchronizedRootGroup` picks them up automatically — no pbxproj editing needed.

**Tech Stack:** Swift, AppKit, NSSegmentedControl, NSTabView, XIB (Interface Builder XML), bash script, ffmpeg loudnorm filter, jq.

---

### Task 1: Bundle normalize_r128.sh and jq in Resources

**Files:**
- Create: `Americo's Media Converter/Resources/normalize_r128.sh`
- Create: `Americo's Media Converter/Resources/jq`

- [ ] **Step 1: Copy the normalize script into Resources**

```bash
cp "/Users/americo/dev/scripts/EBU_R128_Norm/normalize_r128.sh" \
   "/Users/americo/dev/Xcode Projects/americo-media-converter/Americo's Media Converter/Resources/normalize_r128.sh"
```

- [ ] **Step 2: Copy the jq binary into Resources**

`jq` is required by the script. Copy the system-installed binary:

```bash
JQ_PATH=$(which jq 2>/dev/null || ls /opt/homebrew/bin/jq /usr/local/bin/jq 2>/dev/null | head -1)
echo "Using jq from: $JQ_PATH"
cp "$JQ_PATH" "/Users/americo/dev/Xcode Projects/americo-media-converter/Americo's Media Converter/Resources/jq"
chmod +x "/Users/americo/dev/Xcode Projects/americo-media-converter/Americo's Media Converter/Resources/jq"
```

- [ ] **Step 3: Verify both files are in place and executable**

```bash
ls -la "/Users/americo/dev/Xcode Projects/americo-media-converter/Americo's Media Converter/Resources/"
```

Expected: `normalize_r128.sh` and `jq` listed. `jq` must show `x` in permissions.

- [ ] **Step 4: Build to confirm Resources are picked up**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
xcodebuild -project "Americo's Media Converter.xcodeproj" \
           -scheme "americo-medio-converter" \
           -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
git add "Americo's Media Converter/Resources/normalize_r128.sh" \
        "Americo's Media Converter/Resources/jq"
git commit -m "Bundle normalize_r128.sh and jq in Resources

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Add .normalize to ConversionType

**Files:**
- Modify: `Americo's Media Converter/Controllers/Constants.swift:30-33`

- [ ] **Step 1: Add the .normalize case**

In `Constants.swift`, find:

```swift
    enum ConversionType {
        case audio
        case video
    }
```

Replace with:

```swift
    enum ConversionType {
        case audio
        case video
        case normalize
    }
```

- [ ] **Step 2: Build to confirm no regressions**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
xcodebuild -project "Americo's Media Converter.xcodeproj" \
           -scheme "americo-medio-converter" \
           -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
git add "Americo's Media Converter/Controllers/Constants.swift"
git commit -m "Add .normalize case to ConversionType

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Add normalize() to Converter.swift

**Files:**
- Modify: `Americo's Media Converter/Converters/Converter.swift`

- [ ] **Step 1: Add the normalize() method**

In `Converter.swift`, insert the following before the `cancelAllProcesses()` method (before the line `func cancelAllProcesses() {`):

```swift
    func normalize(file: mediaFile,
                   targetLUFS: Int,
                   scriptURL: URL,
                   resourcesURL: URL,
                   row: Int,
                   completion: @escaping (Bool, String?, Int32) -> Void) {
        delegate?.showProgressBar(row)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, "-i", "\(targetLUFS).0", file.mfURL.path]
        process.environment = ["PATH": "\(resourcesURL.path):/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        let fileHandle = outputPipe.fileHandleForReading

        var outputBuffer = ""
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            outputBuffer += chunk
            let lines = outputBuffer.components(separatedBy: "\n")
            outputBuffer = lines.last ?? ""
            for line in lines.dropLast() {
                guard !line.isEmpty else { continue }
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.shouldUpdateOutView(line + "\n", Constants.MessageAttribute.regularMessageAttributes)
                    if line.contains("Pass 1/2") { self?.delegate?.conversionProgress(forRow: row, 0.3) }
                    else if line.contains("Pass 2/2") { self?.delegate?.conversionProgress(forRow: row, 0.7) }
                    else if line.contains("[OK]") { self?.delegate?.conversionProgress(forRow: row, 1.0) }
                }
            }
        }

        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                if status == 0 {
                    self?.delegate?.shouldUpdateOutView(
                        "\nNormalization of \(file.mfURL.lastPathComponent) complete.\n",
                        Constants.MessageAttribute.succesMessageAttributes)
                } else {
                    self?.delegate?.shouldUpdateOutView(
                        "\nNormalization of \(file.mfURL.lastPathComponent) failed with status \(status).\n",
                        Constants.MessageAttribute.errorMessageAttributes)
                }
                completion(status == 0, nil, status)
            }
            self?.runningProcesses.remove(process)
        }

        runningProcesses.insert(process)

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                self.delegate?.shouldUpdateOutView(
                    "\(file.mfURL.lastPathComponent): Failed to start normalization: \(error.localizedDescription)\n",
                    Constants.MessageAttribute.errorMessageAttributes)
                completion(false, error.localizedDescription, -1)
            }
        }
    }

```

- [ ] **Step 2: Build to confirm no errors**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
xcodebuild -project "Americo's Media Converter.xcodeproj" \
           -scheme "americo-medio-converter" \
           -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
git add "Americo's Media Converter/Converters/Converter.swift"
git commit -m "Add normalize() method to Converter

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Add Normalize tab to MainMenu.xib

**Files:**
- Modify: `Americo's Media Converter/Base.lproj/MainMenu.xib`

This task has two separate edits to the XIB: (A) add the tab content and (B) add the outlet connections.

**Edit A — Insert the Normalize tabViewItem**

Find this exact string (the closing tag of the Video tabViewItem followed by the closing tabViewItems tag):

```xml
                            </tabViewItem>
                        </tabViewItems>
                    </tabView>
```

Replace with:

```xml
                            </tabViewItem>
                            <tabViewItem label="Normalize" identifier="" image="waveform" catalog="system" id="nrm-TP-tab">
                                <view key="view" id="nrm-Vw-001">
                                    <rect key="frame" x="10" y="33" width="894" height="450"/>
                                    <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                                    <subviews>
                                        <textField horizontalHuggingPriority="251" verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="nrm-LB-001">
                                            <rect key="frame" x="17" y="431" width="133" height="16"/>
                                            <autoresizingMask key="autoresizingMask" flexibleMaxX="YES" flexibleMinY="YES"/>
                                            <textFieldCell key="cell" lineBreakMode="clipping" title="Target LUFS" id="nrm-LC-001">
                                                <font key="font" metaFont="system"/>
                                                <color key="textColor" name="labelColor" catalog="System" colorSpace="catalog"/>
                                                <color key="backgroundColor" name="textBackgroundColor" catalog="System" colorSpace="catalog"/>
                                            </textFieldCell>
                                        </textField>
                                        <segmentedControl fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="nrm-SC-001">
                                            <rect key="frame" x="14" y="396" width="420" height="28"/>
                                            <autoresizingMask key="autoresizingMask" flexibleMaxX="YES" flexibleMinY="YES"/>
                                            <segmentedCell key="cell" borderStyle="border" alignment="left" style="rounded" trackingMode="selectOne" id="nrm-SCC-01">
                                                <font key="font" metaFont="system"/>
                                                <segments>
                                                    <segment label="-23 LUFS (EBU R128)" selected="YES"/>
                                                    <segment label="-16 LUFS"/>
                                                    <segment label="-14 LUFS"/>
                                                    <segment label="-12 LUFS"/>
                                                </segments>
                                            </segmentedCell>
                                        </segmentedControl>
                                        <scrollView fixedFrame="YES" borderType="none" horizontalLineScroll="10" horizontalPageScroll="10" verticalLineScroll="10" verticalPageScroll="10" hasHorizontalScroller="NO" translatesAutoresizingMaskIntoConstraints="NO" id="nrm-SV-001">
                                            <rect key="frame" x="17" y="17" width="860" height="360"/>
                                            <autoresizingMask key="autoresizingMask"/>
                                            <clipView key="contentView" drawsBackground="NO" id="nrm-CV-001">
                                                <rect key="frame" x="0.0" y="0.0" width="843" height="360"/>
                                                <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                                                <subviews>
                                                    <textView wantsLayer="YES" editable="NO" importsGraphics="NO" richText="NO" verticallyResizable="YES" selectionGranularity="word" allowsCharacterPickerTouchBarItem="NO" textCompletion="NO" id="nrm-TV-001">
                                                        <rect key="frame" x="0.0" y="0.0" width="843" height="360"/>
                                                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                                                        <color key="textColor" name="systemGreenColor" catalog="System" colorSpace="catalog"/>
                                                        <color key="backgroundColor" name="textBackgroundColor" catalog="System" colorSpace="catalog"/>
                                                        <size key="minSize" width="843" height="360"/>
                                                        <size key="maxSize" width="860" height="10000000"/>
                                                    </textView>
                                                </subviews>
                                            </clipView>
                                            <scroller key="horizontalScroller" hidden="YES" verticalHuggingPriority="750" horizontal="YES" id="nrm-HS-001">
                                                <rect key="frame" x="-100" y="-100" width="225" height="15"/>
                                                <autoresizingMask key="autoresizingMask"/>
                                            </scroller>
                                            <scroller key="verticalScroller" verticalHuggingPriority="750" horizontal="NO" id="nrm-VS-001">
                                                <rect key="frame" x="843" y="0.0" width="17" height="360"/>
                                                <autoresizingMask key="autoresizingMask"/>
                                            </scroller>
                                        </scrollView>
                                    </subviews>
                                </view>
                            </tabViewItem>
                        </tabViewItems>
                    </tabView>
```

**Edit B — Add outlet connections**

Find this exact string in the MVC connections block:

```xml
                <outlet property="videoTabView" destination="piW-l2-exh" id="Vt8-AK-pgH"/>
                <outlet property="view" destination="EiT-Mj-1SZ" id="Pto-9c-agM"/>
```

Replace with:

```xml
                <outlet property="videoTabView" destination="piW-l2-exh" id="Vt8-AK-pgH"/>
                <outlet property="normalizeTabView" destination="nrm-TP-tab" id="nrm-OV-001"/>
                <outlet property="normalizeLUFSControl" destination="nrm-SC-001" id="nrm-OC-001"/>
                <outlet property="normalizeOutTextView" destination="nrm-TV-001" id="nrm-OT-001"/>
                <outlet property="view" destination="EiT-Mj-1SZ" id="Pto-9c-agM"/>
```

- [ ] **Step 1: Apply Edit A (Normalize tabViewItem)**

Use the Edit tool with the find/replace strings above.

- [ ] **Step 2: Apply Edit B (outlet connections)**

Use the Edit tool with the find/replace strings above.

- [ ] **Step 3: Build to confirm XIB parses correctly**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
xcodebuild -project "Americo's Media Converter.xcodeproj" \
           -scheme "americo-medio-converter" \
           -configuration Debug build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **` with no IBOutlet warnings.

- [ ] **Step 4: Commit**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
git add "Americo's Media Converter/Base.lproj/MainMenu.xib"
git commit -m "Add Normalize tab to MainMenu.xib

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Wire MVC.swift

**Files:**
- Modify: `Americo's Media Converter/Controllers/MVC.swift`

Four edits in this file.

**Edit A — Add Normalize IBOutlets**

Find:

```swift
    @IBOutlet weak var videoPadButton: NSButton!


    // MARK: Media related variables
```

Replace with:

```swift
    @IBOutlet weak var videoPadButton: NSButton!


    // MARK: Normalize Outlets
    @IBOutlet weak var normalizeTabView: NSTabViewItem!
    @IBOutlet weak var normalizeLUFSControl: NSSegmentedControl!
    @IBOutlet weak var normalizeOutTextView: NSTextView!


    // MARK: Media related variables
```

**Edit B — Clear normalizeOutTextView in startConversion and add "Normalize" case**

Find:

```swift
        audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        videoOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
```

Replace with:

```swift
        audioOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        videoOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        normalizeOutTextView.textStorage?.setAttributedString(NSAttributedString(string: ""))
```

Find:

```swift
            case "Video":
                resetAllProgressBar()
                conversionType = .video
                convertVideo()
                break
            default:
```

Replace with:

```swift
            case "Video":
                resetAllProgressBar()
                conversionType = .video
                convertVideo()
                break
            case "Normalize":
                resetAllProgressBar()
                conversionType = .normalize
                convertNormalize()
                break
            default:
```

**Edit C — Add convertNormalize() method**

Find the line:

```swift
    //MARK: NSTabView delegate methods
```

Insert the following immediately before it:

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

**Edit D — Add .normalize case to shouldUpdateOutView**

Find:

```swift
            case .video:
                videoOutTextView.textStorage?.append(NSAttributedString(string: text, attributes: attr))
                scrollToBottom(videoOutTextView)
            default:
```

Replace with:

```swift
            case .video:
                videoOutTextView.textStorage?.append(NSAttributedString(string: text, attributes: attr))
                scrollToBottom(videoOutTextView)
            case .normalize:
                normalizeOutTextView.textStorage?.append(NSAttributedString(string: text, attributes: attr))
                scrollToBottom(normalizeOutTextView)
            default:
```

- [ ] **Step 1: Apply Edit A (IBOutlets)**
- [ ] **Step 2: Apply Edit B (clear in startConversion + Normalize case)**
- [ ] **Step 3: Apply Edit C (convertNormalize method)**
- [ ] **Step 4: Apply Edit D (shouldUpdateOutView .normalize case)**

- [ ] **Step 5: Build**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
xcodebuild -project "Americo's Media Converter.xcodeproj" \
           -scheme "americo-medio-converter" \
           -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
git add "Americo's Media Converter/Controllers/MVC.swift"
git commit -m "Wire Normalize tab in MVC: outlets, convertNormalize(), startConversion branch

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 6: End-to-end verification

- [ ] **Step 1: Launch the app**

Build and run from Xcode, or:

```bash
cd "/Users/americo/dev/Xcode Projects/americo-media-converter"
xcodebuild -project "Americo's Media Converter.xcodeproj" \
           -scheme "americo-medio-converter" \
           -configuration Debug build 2>&1 | grep "CONFIGURATION_BUILD_DIR"
# Then open the .app from the build dir
```

- [ ] **Step 2: Verify the Normalize tab appears**

Click the Normalize tab. Confirm: three tabs visible (Audio, Video, Normalize), segmented control shows four segments with -23 LUFS (EBU R128) selected by default, output log area is empty.

- [ ] **Step 3: Test with a WAV file at -23 LUFS**

Drop a WAV file into the file queue. Select the Normalize tab. Leave -23 LUFS selected. Click Convert.

Expected:
- Progress bar starts, advances to ~30% (Pass 1 analysis), then ~70% (Pass 2 applying), then 100% (done)
- Output log shows `[INFO] Pass 1/2`, `[INFO] Measured`, `[INFO] Pass 2/2`, `[OK] Done`
- A new file appears in the same folder as the input with suffix `_EBU_R128(-23LUFS)`

- [ ] **Step 4: Test with a non-default target (-14 LUFS)**

Select -14 LUFS. Drop a WAV file. Click Convert.

Expected: Output file has suffix `_(-14LUFS)`.

- [ ] **Step 5: Test error handling**

Drop a video-only file (e.g. a .mov with no audio). Click Convert on the Normalize tab.

Expected: Script exits with status 1. Output log shows error message. Progress bar turns red.

- [ ] **Step 6: Test cancel**

Start a normalization of a large file. Click Cancel immediately.

Expected: Process stops, no output file left behind (script cleans up its temp file).
