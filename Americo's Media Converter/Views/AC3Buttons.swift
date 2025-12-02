//
//  AC3Buttons.swift
//  americo-media-converter
//
//  Created by Americo Cot on 26/11/25.
//

import Cocoa

class AC3Buttons: NSButton {

    // MARK: - Inspectable Properties
    
    @IBInspectable var cornerRadius: CGFloat = 2 {
        didSet { updateLayer() }
    }
    
    @IBInspectable var backgroundColor: NSColor = .darkGray {
        didSet { updateLayer() }
    }
    
    @IBInspectable var hoverColor: NSColor = .systemIndigo {
        didSet { updateLayer() }
    }

    @IBInspectable var textColor: NSColor = .lightGray {
        didSet { updateAttributedTitle() }
    }

    @IBInspectable var customFontSize: CGFloat = 16 {
        didSet { updateAttributedTitle() }
    }

    @IBInspectable var customFontName: String = "Helvetica Neue" {
        didSet { updateAttributedTitle() }
    }

    private var trackingArea: NSTrackingArea?

    // MARK: - Initializers

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        
        updateLayer()
        updateAttributedTitle()
    }

    // MARK: - Appearance

    override func updateLayer() {
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.cornerRadius = cornerRadius
    }

    private func updateAttributedTitle() {
        let font = NSFont(name: customFontName, size: customFontSize) ?? NSFont.systemFont(ofSize: customFontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: font
        ]

        attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    // MARK: - Hover Effect

    override func updateTrackingAreas() {
        if let area = trackingArea {
            removeTrackingArea(area)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = hoverColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = backgroundColor.cgColor
    }

    // MARK: - Custom Size Control

    // override var intrinsicContentSize: NSSize {
    //     return NSSize(width: 400, height: 50)
    // }
}
