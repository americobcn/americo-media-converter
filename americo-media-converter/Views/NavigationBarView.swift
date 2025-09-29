import Cocoa

protocol NavigationBarDelegate: AnyObject {
    func didSelectView(_ view: NSView)
}

class NavigationBarView: NSView {
    weak var delegate: NavigationBarDelegate?
    private var buttons: [NSButton] = []
    private let views: [NSView]
    
    init(frame: NSRect, views: [NSView]) {
        self.views = views
        super.init(frame: frame)
        configureAppearance()
        createButtons()
    }
    
    required init?(coder: NSCoder) {
        self.views = []
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
    }
    
    private func configureAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.08, alpha: 1).cgColor  //.green.cgColor
        layer?.cornerRadius = 5
    }
    
    private func createButtons() {
        let buttonTitles = ["Audio", "Video"]
        let buttonIcons = ["hifispeaker", "video"] // SF Symbols
        
        for (index, title) in buttonTitles.enumerated() {
            let button = NSButton(title: title, target: self, action: #selector(buttonTapped(_:)))
            button.bezelStyle = .smallSquare  //.shadowlessSquare
            button.image = NSImage(systemSymbolName: buttonIcons[index], accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            button.contentTintColor = .white
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 1).cgColor //NSColor.darkGray.cgColor
            button.layer?.cornerRadius = 4
            button.tag = index
            print("Adding Buttons")
            buttons.append(button)
            addSubview(button)
        }
    }
    
    override func layout() {
        super.layout()
        let buttonWidth: CGFloat = 125  // frame.width / CGFloat(buttons.count)
        let buttonHeight: CGFloat = 30  // frame.height / 1.5
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * buttonWidth + 5, y: bounds.height - buttonHeight - 5, width: buttonWidth - 10, height: buttonHeight)
        }
    }
    
    @objc private func buttonTapped(_ sender: NSButton) {
        let selectedIndex = sender.tag
        if selectedIndex < buttons.count {
            // delegate?.didSelectView(views[selectedIndex])
        }
    }
}


/*
 // Usage Example in a ViewController
 class MainViewController: NSViewController, NavigationBarDelegate {
 private var contentView: NSView!
 
 override func loadView() {
 view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
 contentView = NSView(frame: NSRect(x: 0, y: 50, width: 800, height: 550))
 view.addSubview(contentView)
 
 let homeView = NSView(frame: contentView.bounds)
 homeView.wantsLayer = true
 homeView.layer?.backgroundColor = NSColor.systemBlue.cgColor
 
 let settingsView = NSView(frame: contentView.bounds)
 settingsView.wantsLayer = true
 settingsView.layer?.backgroundColor = NSColor.systemGreen.cgColor
 
 let profileView = NSView(frame: contentView.bounds)
 profileView.wantsLayer = true
 profileView.layer?.backgroundColor = NSColor.systemRed.cgColor
 
 let navBar = NavigationBar(frame: NSRect(x: 0, y: 550, width: 800, height: 50), views: [homeView, settingsView, profileView])
 navBar.delegate = self
 view.addSubview(navBar)
 }
 
 func didSelectView(_ view: NSView) {
 contentView.subviews.forEach { $0.removeFromSuperview() }
 contentView.addSubview(view)
 }
 }
 */
