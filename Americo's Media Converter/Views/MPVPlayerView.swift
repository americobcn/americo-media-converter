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

// MARK: - Player view

final class MPVPlayerView: NSView {

    fileprivate var mpvHandle: OpaquePointer?
    fileprivate var renderContext: OpaquePointer?
    private var glLayer: MPVGLLayer? { layer as? MPVGLLayer }
    private var eventThread: Thread?
    private var trackingArea: NSTrackingArea?

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
        startEventLoop()
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
            ("osc", "yes"),
            ("input-default-bindings", "yes"),
            ("input-vo-keyboard", "yes"),
            ("input-cursor", "yes"),
            ("cursor-autohide", "1000"),
            ("ytdl", "no")
        ]
        for (key, value) in options {
            mpv_set_option_string(mpv, key, value)
        }
        mpv_request_log_messages(mpv, "error")
        if mpv_initialize(mpv) < 0 {
            NSLog("MPVPlayerView: mpv_initialize() failed")
        }
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
        let thread = Thread {
            while true {
                guard let eventPtr = mpv_wait_event(mpv, -1) else { continue }
                let event = eventPtr.pointee
                if event.event_id == MPV_EVENT_SHUTDOWN { break }
                if event.event_id == MPV_EVENT_LOG_MESSAGE, let data = event.data {
                    let message = data.assumingMemoryBound(to: mpv_event_log_message.self).pointee
                    NSLog("[mpv] %@", String(cString: message.prefix) + ": " + String(cString: message.text))
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
        command(["cycle", "pause"])
    }

    func clear() {
        command(["stop"])
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

    // MARK: Mouse input → on-screen controller

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    private func mpvCoordinates(for event: NSEvent) -> (Int, Int) {
        let point = convert(event.locationInWindow, from: nil)
        let scale = window?.backingScaleFactor ?? 1.0
        return (Int(point.x * scale), Int((bounds.height - point.y) * scale))
    }

    override func mouseMoved(with event: NSEvent) {
        let (x, y) = mpvCoordinates(for: event)
        command(["mouse", "\(x)", "\(y)"])
    }

    override func mouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let (x, y) = mpvCoordinates(for: event)
        command(["mouse", "\(x)", "\(y)", "0", "single"])
    }
}
