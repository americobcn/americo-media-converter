//
//  CustomCellView.swift
//  MyApp
//
//  Created by Américo Cot Toloza on 23/3/25.
//

import Cocoa

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
        addSubview(cellImageView)
        addSubview(fileNameLabel)
        addSubview(fileInfoLabel)

        cellImageView.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileInfoLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // ImageView constraints
            cellImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            cellImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cellImageView.widthAnchor.constraint(equalToConstant: 40),
            cellImageView.heightAnchor.constraint(equalToConstant: 40),

            // FileName label
            fileNameLabel.leadingAnchor.constraint(equalTo: cellImageView.trailingAnchor, constant: 10),
            fileNameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            fileNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // FileInfo label
            fileInfoLabel.leadingAnchor.constraint(equalTo: cellImageView.trailingAnchor, constant: 10),
            fileInfoLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 1),
            fileInfoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            fileInfoLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -5)
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
    
}
