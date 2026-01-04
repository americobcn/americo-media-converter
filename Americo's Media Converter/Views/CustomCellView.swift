//
//  CustomCellView.swift
//  MyApp
//
//  Created by Américo Cot Toloza on 23/3/25.
//

import Cocoa
// import QuartzCore

final class CustomCellView: NSTableCellView {
    
    // MARK: - UI Elements
    let fileNameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 0.7)
        label.isEditable = false
        label.isBezeled = false
        label.backgroundColor = .clear
        return label
    }()

     let fileInfoLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.isEditable = false
        label.isBezeled = false
        label.backgroundColor = .clear
        return label
    }()
    
     let cellImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = NSColor(calibratedRed: 0.1, green: 1, blue: 0.1, alpha: 0.5)
        return imageView
    }()

    let progressView: AC3ProgressIndicator = AC3ProgressIndicator()
    
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    

    // MARK: - Layout
    private func setupViews() {
        // progressView.setupAsDeterminateSpin(minValue: 0, maxValue: 100)
        addSubview(cellImageView)
        addSubview(fileNameLabel)
        addSubview(fileInfoLabel)
        addSubview(progressView)
        
        cellImageView.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // ImageView constraints
            cellImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            cellImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cellImageView.widthAnchor.constraint(equalToConstant: 40),
            cellImageView.heightAnchor.constraint(equalToConstant: 40),
            
            // progressView constraints
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10.0),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 100),
            progressView.heightAnchor.constraint(equalToConstant: 40),

            // FileName label
            fileNameLabel.leadingAnchor.constraint(equalTo: cellImageView.trailingAnchor, constant: 10),
            fileNameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            fileNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // FileInfo label
            fileInfoLabel.leadingAnchor.constraint(equalTo: cellImageView.trailingAnchor, constant: 10),
            fileInfoLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 1),
            fileInfoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            fileInfoLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -5),
                        
        ])
    }
    
        
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let separatorHeight: CGFloat = 1.0
        let separatorColor = NSColor.separatorColor
        
        // Always draw the bottom border, even for the last row
        let separatorRect = NSRect(
            x: 0,
            y: 0, // Adjust for last row
            width: dirtyRect.width,
            height: separatorHeight
        )

        separatorColor.set()
        separatorRect.fill()
    }
    
    deinit {
        progressView.isHidden = true
        progressView.removeFromSuperview()
        
    }
    
}


/// A custom NSProgressIndicator subclass that animates smoothly between step values
class AC3ProgressIndicator: NSProgressIndicator {
    
    // MARK: - Properties
    
    /// The target progress value to animate towards
    private var targetProgress: Double = 0.0
    
    /// The animation duration for each step transition (in seconds)
    var stepAnimationDuration: TimeInterval = 0.15
    
    /// The display link for smooth animation
    private var displayLink: CVDisplayLink?
    
    /// The start time of the current animation
    private var animationStartTime: TimeInterval = 0
    
    /// The progress value at the start of the animation
    private var animationStartProgress: Double = 0
    
    /// Whether an animation is currently in progress
    private var isAnimating: Bool = false
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDisplayLink()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDisplayLink()
    }
    
    deinit {
        stopDisplayLink()
    }
    
    // MARK: - Setup
    
    private func setupDisplayLink() {
        // Create display link for smooth animation
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        guard let displayLink = displayLink else { return }
        
        // Set the output callback
        CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let indicator = Unmanaged<AC3ProgressIndicator>.fromOpaque(userInfo).takeUnretainedValue()
            
            DispatchQueue.main.async {
                indicator.updateAnimation()
            }
            
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
    }
    
    private func startDisplayLink() {
        guard let displayLink = displayLink else { return }
        if !CVDisplayLinkIsRunning(displayLink) {
            CVDisplayLinkStart(displayLink)
        }
    }
    
    private func stopDisplayLink() {
        guard let displayLink = displayLink else { return }
        if CVDisplayLinkIsRunning(displayLink) {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    // MARK: - Public Methods
    
    /// Sets the progress value with smooth animation
    /// - Parameter progress: The target progress value (0.0 to maxValue)
    func setProgress(_ progress: Double, animated: Bool = true) {
        targetProgress = min(max(progress, minValue), maxValue)
        
        if animated {
            animationStartProgress = doubleValue
            animationStartTime = CACurrentMediaTime()
            isAnimating = true
            startDisplayLink()
        } else {
            doubleValue = targetProgress
            isAnimating = false
            stopDisplayLink()
        }
    }
    
    /// Increments the progress by the specified amount with animation
    /// - Parameter amount: The amount to increment
    func incrementProgress(by amount: Double) {
        setProgress(targetProgress + amount, animated: true)
    }
    
    // MARK: - Animation
    
    private func updateAnimation() {
        guard isAnimating else {
            stopDisplayLink()
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - animationStartTime
        
        // Calculate progress using easing function
        let progress = min(elapsedTime / stepAnimationDuration, 1.0)
        let easedProgress = easeInOutQuad(progress)
        
        // Interpolate between start and target
        let diff = targetProgress - animationStartProgress
        doubleValue = animationStartProgress + (diff * easedProgress)
        
        // Check if animation is complete
        if progress >= 1.0 {
            doubleValue = targetProgress
            isAnimating = false
            stopDisplayLink()
        }
    }
    
    /// Easing function for smooth animation (ease-in-out quadratic)
    private func easeInOutQuad(_ t: Double) -> Double {
        if t < 0.5 {
            return 2 * t * t
        } else {
            return 1 - pow(-2 * t + 2, 2) / 2
        }
    }
}

// MARK: - Example Usage Extension

extension AC3ProgressIndicator {

    /// Convenience method to setup as a determinate progress bar
    func setupAsDeterminateBar(minValue: Double = 0.0, maxValue: Double = 100.0) {
        self.style = .bar
        self.isIndeterminate = false
        self.minValue = minValue
        self.maxValue = maxValue
        self.doubleValue = minValue
        self.isHidden = true
        self.usesThreadedAnimation = true
                
        let color = CIColor(red: 0.1, green: 0.9, blue: 0.1) // Green
        let filter = CIFilter(name: "CIFalseColor", parameters: [
            "inputColor0": color,
            "inputColor1": color
        ])!
        self.contentFilters = [filter]
    }
    
    func setupAsDeterminateSpin(minValue: Double = 0.0, maxValue: Double = 100.0) {
        self.style = .spinning
        self.isIndeterminate = false
        self.minValue = minValue
        self.maxValue = maxValue
        self.doubleValue = minValue
        self.isHidden = true
        self.usesThreadedAnimation = true
        
        let color = CIColor(red: 0.1, green: 0.9, blue: 0.1) // Green
        let filter = CIFilter(name: "CIFalseColor", parameters: [
            "inputColor0": color,
            "inputColor1": color
        ])!
        self.contentFilters = [filter]
    }

}
