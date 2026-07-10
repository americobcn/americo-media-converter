import Cocoa
import OpenGL.GL3

// MARK: - libmpv C callbacks

private func mpvGetProcAddress(_ ctx: UnsafeMutableRawPointer?,
                               _ name: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let name = name,
          let framework = CFBundleGetBundleWithIdentifier("com.apple.opengl" as CFString) else {
        return nil
    }
    let symbol = String(cString: name) as CFString
    return CFBundleGetFunctionPointerForName(framework, symbol)
}

private func mpvRenderUpdate(_ ctx: UnsafeMutableRawPointer?) {
    guard let ctx = ctx else { return }
    Unmanaged<MPVPlayerView>.fromOpaque(ctx).takeUnretainedValue().requestRedraw()
}

// MARK: - GL layer

final class MPVGLLayer: CAOpenGLLayer {
    weak var owner: MPVPlayerView?

    override func copyCGLPixelFormat(forDisplayMask mask: UInt32) -> CGLPixelFormatObj {
        let attributes: [CGLPixelFormatAttribute] = [
            kCGLPFAOpenGLProfile, CGLPixelFormatAttribute(kCGLOGLPVersion_3_2_Core.rawValue),
            kCGLPFAAccelerated,
            kCGLPFADoubleBuffer,
            CGLPixelFormatAttribute(0)
        ]
        var pixelFormat: CGLPixelFormatObj?
        var count: GLint = 0
        CGLChoosePixelFormat(attributes, &pixelFormat, &count)
        return pixelFormat ?? super.copyCGLPixelFormat(forDisplayMask: mask)
    }

    override func canDraw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj,
                          forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) -> Bool {
        return owner?.mpvHandle != nil
    }

    override func draw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj,
                       forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) {
        owner?.ensureRenderContext()
        guard let renderContext = owner?.renderContext else {
            glClearColor(0, 0, 0, 1)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            glFlush()
            return
        }
        var currentFBO: GLint = 0
        glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &currentFBO)
        let scale = contentsScale
        var fbo = mpv_opengl_fbo(fbo: Int32(currentFBO),
                                 w: Int32(bounds.width * scale),
                                 h: Int32(bounds.height * scale),
                                 internal_format: 0)
        var flipY: CInt = 1
        withUnsafeMutablePointer(to: &fbo) { fboPtr in
            withUnsafeMutablePointer(to: &flipY) { flipPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: UnsafeMutableRawPointer(fboPtr)),
                    mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: UnsafeMutableRawPointer(flipPtr)),
                    mpv_render_param()
                ]
                mpv_render_context_render(renderContext, &params)
            }
        }
    }
}

// MARK: - Scrubber slider

private final class ScrubberSlider: NSSlider {
    private(set) var isTracking = false

    override func mouseDown(with event: NSEvent) {
        isTracking = true
        super.mouseDown(with: event)
        isTracking = false
    }
}

// MARK: - Player view

final class MPVPlayerView: NSView {

    fileprivate var mpvHandle: OpaquePointer?
    fileprivate var renderContext: OpaquePointer?
    private var glLayer: MPVGLLayer? { layer as? MPVGLLayer }
    private var eventThread: Thread?
    private var trackingArea: NSTrackingArea?

    private var controlBar: NSVisualEffectView?
    private var playPauseButton: NSButton?
    private var seekSlider: ScrubberSlider?
    private var volumeSlider: ScrubberSlider?
    private var currentTimeLabel: NSTextField?
    private var durationLabel: NSTextField?
    private var hoverPollTimer: Timer?
    private var lastActivity = Date()
    private var isAtEndOfFile = false

    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        setupMPV()
        wantsLayer = true
        glLayer?.contentsScale = 2.0
        setupControlBar()
        startEventLoop()
        startHoverPolling()
    }

    override func makeBackingLayer() -> CALayer {
        let backingLayer = MPVGLLayer()
        backingLayer.owner = self
        backingLayer.isOpaque = true
        backingLayer.isAsynchronous = false
        backingLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        backingLayer.needsDisplayOnBoundsChange = true
        backingLayer.backgroundColor = NSColor.black.cgColor
        return backingLayer
    }

    deinit {
        hoverPollTimer?.invalidate()
        if let renderContext = renderContext {
            mpv_render_context_free(renderContext)
        }
        if let mpvHandle = mpvHandle {
            mpv_terminate_destroy(mpvHandle)
        }
    }

    // MARK: mpv setup

    private func setupMPV() {
        guard let mpv = mpv_create() else {
            NSLog("MPVPlayerView: mpv_create() failed")
            return
        }
        mpvHandle = mpv
        let options: [(String, String)] = [
            ("vo", "libmpv"),
            ("hwdec", "auto-safe"),
            ("pause", "yes"),
            ("keep-open", "yes"),
            ("idle", "yes"),
            ("osc", "no"),
            ("ytdl", "no")
        ]
        for (key, value) in options {
            mpv_set_option_string(mpv, key, value)
        }
        mpv_request_log_messages(mpv, "error")
        if mpv_initialize(mpv) < 0 {
            NSLog("MPVPlayerView: mpv_initialize() failed")
            return
        }
        mpv_observe_property(mpv, 0, "time-pos", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, "volume", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "eof-reached", MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, "mute", MPV_FORMAT_FLAG)
    }

    fileprivate func ensureRenderContext() {
        guard renderContext == nil, let mpv = mpvHandle else { return }
        var initParams = mpv_opengl_init_params(get_proc_address: mpvGetProcAddress,
                                                get_proc_address_ctx: nil)
        let apiType = strdup("opengl")
        defer { free(apiType) }
        withUnsafeMutablePointer(to: &initParams) { initParamsPtr in
            var params = [
                mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(apiType)),
                mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: UnsafeMutableRawPointer(initParamsPtr)),
                mpv_render_param()
            ]
            var context: OpaquePointer?
            if mpv_render_context_create(&context, mpv, &params) >= 0, let context = context {
                renderContext = context
                mpv_render_context_set_update_callback(context, mpvRenderUpdate,
                                                       Unmanaged.passUnretained(self).toOpaque())
            } else {
                NSLog("MPVPlayerView: mpv_render_context_create() failed")
            }
        }
    }

    // MARK: Event loop

    private func startEventLoop() {
        guard let mpv = mpvHandle else { return }
        let thread = Thread { [weak self] in
            while true {
                guard let eventPtr = mpv_wait_event(mpv, -1) else { continue }
                let event = eventPtr.pointee
                if event.event_id == MPV_EVENT_SHUTDOWN { break }
                if event.event_id == MPV_EVENT_LOG_MESSAGE, let data = event.data {
                    let message = data.assumingMemoryBound(to: mpv_event_log_message.self).pointee
                    NSLog("[mpv] %@", String(cString: message.prefix) + ": " + String(cString: message.text))
                }
                if event.event_id == MPV_EVENT_PROPERTY_CHANGE, let propertyData = event.data {
                    let property = propertyData.assumingMemoryBound(to: mpv_event_property.self).pointee
                    let name = String(cString: property.name)
                    if property.format == MPV_FORMAT_DOUBLE, let valuePtr = property.data {
                        let value = valuePtr.assumingMemoryBound(to: Double.self).pointee
                        DispatchQueue.main.async { [weak self] in self?.applyProperty(name, double: value) }
                    } else if property.format == MPV_FORMAT_FLAG, let valuePtr = property.data {
                        let value = valuePtr.assumingMemoryBound(to: Int32.self).pointee
                        DispatchQueue.main.async { [weak self] in self?.applyProperty(name, flag: value) }
                    }
                }
            }
        }
        thread.name = "mpv-events"
        thread.start()
        eventThread = thread
    }

    fileprivate func requestRedraw() {
        DispatchQueue.main.async { [weak self] in
            self?.glLayer?.setNeedsDisplay()
        }
    }

    // MARK: Public API

    func load(url: URL) {
        setPropertyString("pause", "yes")
        let target = url.isFileURL ? url.path : url.absoluteString
        command(["loadfile", target])
    }

    func togglePause() {
        if isAtEndOfFile {
            command(["seek", "0", "absolute"])
            setPropertyString("pause", "no")
        } else {
            command(["cycle", "pause"])
        }
    }

    func clear() {
        command(["stop"])
        seekSlider?.doubleValue = 0
        seekSlider?.maxValue = 1
        currentTimeLabel?.stringValue = "0:00"
        durationLabel?.stringValue = "0:00"
        playPauseButton?.image = Self.symbolImage("play.fill")
        isAtEndOfFile = false
    }

    // MARK: mpv helpers

    private func command(_ args: [String]) {
        guard let mpv = mpvHandle else { return }
        var cArgs: [UnsafePointer<CChar>?] = args.map { strdup($0).map { UnsafePointer($0) } }
        cArgs.append(nil)
        mpv_command(mpv, &cArgs)
        for pointer in cArgs where pointer != nil { free(UnsafeMutablePointer(mutating: pointer)) }
    }

    private func setPropertyString(_ name: String, _ value: String) {
        guard let mpv = mpvHandle else { return }
        mpv_set_property_string(mpv, name, value)
    }

    // MARK: Backing scale

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        glLayer?.contentsScale = window?.backingScaleFactor ?? 2.0
        glLayer?.setNeedsDisplay()
    }

    // MARK: Control bar UI

    private static func symbolImage(_ name: String) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true
        return image
    }

    private func makeControlButton(symbol: String, action: Selector) -> NSButton {
        let button = NSButton(image: Self.symbolImage(symbol), target: self, action: action)
        button.isBordered = false
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 26).isActive = true
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return button
    }

    private func makeTimeLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "0:00")
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 42).isActive = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    private func setupControlBar() {
        let bar = NSVisualEffectView()
        bar.material = .hudWindow
        bar.blendingMode = .withinWindow
        bar.state = .active
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 8
        bar.layer?.masksToBounds = true
        bar.alphaValue = 0
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        controlBar = bar

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            bar.heightAnchor.constraint(equalToConstant: 40)
        ])

        let startButton = makeControlButton(symbol: "backward.end.fill", action: #selector(goToStartTapped))
        let playPause = makeControlButton(symbol: "play.fill", action: #selector(playPauseTapped))
        let endButton = makeControlButton(symbol: "forward.end.fill", action: #selector(goToEndTapped))
        let subtitleButton = makeControlButton(symbol: "captions.bubble", action: #selector(cycleSubtitlesTapped))
        let audioButton = makeControlButton(symbol: "speaker.wave.2.fill", action: #selector(muteToggledTapped))
        playPauseButton = playPause

        let currentTime = makeTimeLabel()
        let duration = makeTimeLabel()
        currentTimeLabel = currentTime
        durationLabel = duration

        let seek = ScrubberSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(seekSliderChanged))
        seek.isContinuous = true
        seek.translatesAutoresizingMaskIntoConstraints = false
        seek.setContentHuggingPriority(.defaultLow, for: .horizontal)
        seekSlider = seek

        let volume = ScrubberSlider(value: 100, minValue: 0, maxValue: 100, target: self, action: #selector(volumeSliderChanged))
        volume.isContinuous = true
        volume.translatesAutoresizingMaskIntoConstraints = false
        volume.widthAnchor.constraint(equalToConstant: 80).isActive = true
        volumeSlider = volume

        let stack = NSStackView(views: [
            startButton, playPause, endButton,
            currentTime, seek, duration,
            subtitleButton, audioButton, volume
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor)
        ])
    }

    // MARK: Control bar actions

    @objc private func playPauseTapped() {
        togglePause()
    }

    @objc private func goToStartTapped() {
        command(["seek", "0", "absolute"])
    }

    @objc private func goToEndTapped() {
        command(["seek", "100", "absolute-percent"])
    }

    @objc private func cycleSubtitlesTapped() {
        command(["cycle", "sub"])
    }

    @objc private func muteToggledTapped() {
        command(["cycle", "mute"])
    }

    @objc private func seekSliderChanged() {
        guard let seekSlider = seekSlider else { return }
        command(["seek", "\(seekSlider.doubleValue)", "absolute"])
    }

    @objc private func volumeSliderChanged() {
        guard let volumeSlider = volumeSlider else { return }
        command(["set", "volume", "\(Int(volumeSlider.doubleValue))"])
    }

    // MARK: Property updates

    private func applyProperty(_ name: String, double value: Double) {
        switch name {
            case "time-pos":
                if seekSlider?.isTracking != true {
                    seekSlider?.doubleValue = value
                }
                currentTimeLabel?.stringValue = Self.formatTime(value)
                break
            case "duration":
                seekSlider?.maxValue = value
                durationLabel?.stringValue = Self.formatTime(value)
                break
            case "volume":
                if volumeSlider?.isTracking != true {
                    volumeSlider?.doubleValue = value
                }
                break
            default:
                break
        }
    }

    private func applyProperty(_ name: String, flag value: Int32) {
        switch name {
            case "pause":
                playPauseButton?.image = Self.symbolImage(value != 0 ? "play.fill" : "pause.fill")
                break
            case "eof-reached":
                isAtEndOfFile = value != 0
                break
            default:
                break
        }
    }

    private static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: Hover show/hide

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        lastActivity = Date()
        showControlBar()
    }

    override func mouseMoved(with event: NSEvent) {
        lastActivity = Date()
        showControlBar()
    }

    override func mouseExited(with event: NSEvent) {
        lastActivity = Date(timeIntervalSinceNow: -2.5)
    }

    private func showControlBar() {
        guard let controlBar = controlBar, controlBar.alphaValue != 1 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            controlBar.animator().alphaValue = 1
        }
    }

    private func hideControlBar() {
        guard let controlBar = controlBar, controlBar.alphaValue != 0 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            controlBar.animator().alphaValue = 0
        }
    }

    private func startHoverPolling() {
        hoverPollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollHoverState()
        }
    }

    private func pollHoverState() {
        guard let controlBar = controlBar, let window = window else { return }
        let screenPoint = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let viewPoint = convert(windowPoint, from: nil)

        if controlBar.frame.contains(viewPoint) {
            lastActivity = Date()
            showControlBar()
            return
        }
        if bounds.contains(viewPoint) && Date().timeIntervalSince(lastActivity) < 2.5 {
            showControlBar()
            return
        }
        hideControlBar()
    }
}
