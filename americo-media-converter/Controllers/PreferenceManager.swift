//
//  PreferenceManager.swift
//  americo-media-converter
//
//  Created by Américo Cot on 10/10/25.
//

import Cocoa

// MARK: - Preferences Manager
class PreferencesManager {
    static let shared = PreferencesManager()
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let isNotificationsEnabled = "isNotificationsEnabled"
        static let defaultVideoDestination = "defaultVideoDestination"
        static let defaultAudioDestination = "defaultAudioDestination"
    }
    
    private init() {}
    
    // MARK: - Getters
    var defaultVideoDestination: String {
        get { defaults.string(forKey: Keys.defaultVideoDestination) ?? "" }
        set { defaults.set(newValue, forKey: Keys.defaultVideoDestination) }
    }
    
    var defaultAudioDestination: String {
        get { defaults.string(forKey: Keys.defaultAudioDestination) ?? "" }
        set { defaults.set(newValue, forKey: Keys.defaultAudioDestination) }
    }
    
    
    var isNotificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.isNotificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.isNotificationsEnabled) }
    }
        
    
    func resetToDefaults() {
        isNotificationsEnabled = false
        defaultAudioDestination = ""
        defaultVideoDestination = ""
    }
    
}


// MARK: - Preferences Window Controller
class PreferencesWindowController: NSWindowController {
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Preferences"
        window.center()
        
        self.init(window: window)
        
        let preferencesViewController = PreferencesViewController()
        window.contentViewController = preferencesViewController
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
}


// MARK: - Preferences View Controller with Tab View
class PreferencesViewController: NSViewController {
    private var tabView: NSTabView!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabView()
    }
    
    private func setupTabView() {
        tabView = NSTabView(frame: view.bounds)
        tabView.autoresizingMask = [.width, .height]
        tabView.tabViewType = .topTabsBezelBorder
        
        // General Tab
        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = "General"
        generalTab.viewController = GeneralPreferencesViewController()
        tabView.addTabViewItem(generalTab)

        // Notifications Tab
        let notificationsTab = NSTabViewItem(identifier: "notifications")
        notificationsTab.label = "Notifications"
        // notificationsTab.viewController = NotificationsPreferencesViewController()
        tabView.addTabViewItem(notificationsTab)
        
        view.addSubview(tabView)
    }
}


// MARK: - General Preferences View Controller
class GeneralPreferencesViewController: NSViewController {
    
    private let prefs = PreferencesManager.shared
    private var defaultAudioDestinationField: NSTextField!
    private var defaultVideoDestinationField: NSTextField!
    private var resetButton: NSButton!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPreferences()
    }
    
    private func setupUI() {
        
        // Video Destination Label
        let defaultVideoDestinationLabel = NSTextField(labelWithString: "Video destination:")
        defaultVideoDestinationLabel.frame = NSRect(x: 20, y: 250, width: 110, height: 20)
        view.addSubview(defaultVideoDestinationLabel)
        
        // Audio Destination Text Field
        defaultVideoDestinationField = NSTextField(frame: NSRect(x: 140, y: 248, width: 250, height: 24))
        defaultVideoDestinationField.placeholderString = "Path to folder"
        defaultVideoDestinationField.target = self
        defaultVideoDestinationField.action = #selector(videoDestinationChanged)
        view.addSubview(defaultVideoDestinationField)
        
        
        // Audio Destination Label
        let defaultAudioDestinationLabel = NSTextField(labelWithString: "Audio destination:")
        defaultAudioDestinationLabel.frame = NSRect(x: 20, y: 200, width: 110, height: 20)
        view.addSubview(defaultAudioDestinationLabel)
        
        // Audio Destination Text Field
        defaultAudioDestinationField = NSTextField(frame: NSRect(x: 140, y: 198, width: 250, height: 24))
        defaultAudioDestinationField.placeholderString = "Path to folder"
        defaultAudioDestinationField.target = self
        defaultAudioDestinationField.action = #selector(audioDestinationChanged)
        view.addSubview(defaultAudioDestinationField)
                
        
        // Reset Button
        resetButton = NSButton(frame: NSRect(x: 350, y: 20, width: 110, height: 32))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        view.addSubview(resetButton)
    }
        
    
    private func loadPreferences() {
        defaultVideoDestinationField.stringValue = prefs.defaultVideoDestination
        defaultAudioDestinationField.stringValue = prefs.defaultAudioDestination
    }
    
    
    @objc private func audioDestinationChanged() {
        prefs.defaultAudioDestination = defaultAudioDestinationField.stringValue
    }
    
    @objc private func videoDestinationChanged() {
        prefs.defaultVideoDestination = defaultVideoDestinationField.stringValue
    }
    
    @objc private func resetToDefaults() {
        prefs.resetToDefaults()
        loadPreferences()
        
        // Notify other view controllers to refresh
        NotificationCenter.default.post(name: NSNotification.Name("PreferencesDidReset"), object: nil)
    }
}



/*
 // MARK: - Appearance Preferences View Controller
 class AppearancePreferencesViewController: NSViewController {
 
 private let prefs = PreferencesManager.shared
 private var darkModeCheckbox: NSButton!
 private var themePopup: NSPopUpButton!
 private var fontSizeSlider: NSSlider!
 private var fontSizeLabel: NSTextField!
 
 override func loadView() {
 self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
 }
 
 override func viewDidLoad() {
 super.viewDidLoad()
 setupUI()
 loadPreferences()
 
 NotificationCenter.default.addObserver(
 self,
 selector: #selector(preferencesDidReset),
 name: NSNotification.Name("PreferencesDidReset"),
 object: nil
 )
 }
 
 private func setupUI() {
 // Dark Mode Checkbox
 // darkModeCheckbox = NSButton(checkboxWithTitle: "Enable Dark Mode", target: self, action: #selector(darkModeChanged))
 // darkModeCheckbox.frame = NSRect(x: 20, y: 250, width: 200, height: 20)
 // view.addSubview(darkModeCheckbox)
 
 // Theme Label
 // let themeLabel = NSTextField(labelWithString: "Theme Color:")
 // themeLabel.frame = NSRect(x: 20, y: 210, width: 100, height: 20)
 // view.addSubview(themeLabel)
 
 // Theme Popup Button
 // themePopup = NSPopUpButton(frame: NSRect(x: 130, y: 205, width: 150, height: 26))
 // themePopup.addItems(withTitles: ["Blue", "Green", "Purple", "Orange"])
 // themePopup.target = self
 // themePopup.action = #selector(themeChanged)
 // view.addSubview(themePopup)
 
 // Font Size Label
 // let fontLabel = NSTextField(labelWithString: "Font Size:")
 // fontLabel.frame = NSRect(x: 20, y: 170, width: 100, height: 20)
 // view.addSubview(fontLabel)
 
 // Font Size Slider
 // fontSizeSlider = NSSlider(frame: NSRect(x: 130, y: 170, width: 280, height: 20))
 // fontSizeSlider.minValue = 10
 // fontSizeSlider.maxValue = 24
 // fontSizeSlider.numberOfTickMarks = 15
 // fontSizeSlider.allowsTickMarkValuesOnly = true
 // fontSizeSlider.target = self
 // fontSizeSlider.action = #selector(fontSizeChanged)
 // view.addSubview(fontSizeSlider)
 
 // Font Size Value Label
 // fontSizeLabel = NSTextField(labelWithString: "14")
 // fontSizeLabel.frame = NSRect(x: 420, y: 170, width: 40, height: 20)
 // fontSizeLabel.alignment = .right
 // view.addSubview(fontSizeLabel)
 }
 
 private func loadPreferences() {
 // darkModeCheckbox.state = prefs.isDarkMode ? .on : .off
 // themePopup.selectItem(withTitle: prefs.selectedTheme)
 // fontSizeSlider.doubleValue = prefs.fontSize
 // fontSizeLabel.stringValue = "\(Int(prefs.fontSize))"
 }
 
 
 @objc private func preferencesDidReset() {
 loadPreferences()
 }
 
 deinit {
 NotificationCenter.default.removeObserver(self)
 }
 }
 
 
 // MARK: - Notifications Preferences View Controller
 class NotificationsPreferencesViewController: NSViewController {
     
     private let prefs = PreferencesManager.shared
     private var notificationsCheckbox: NSButton!
     private var statusLabel: NSTextField!
     
     override func loadView() {
         self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
     }
     
     override func viewDidLoad() {
         super.viewDidLoad()
         setupUI()
         loadPreferences()
         
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(preferencesDidReset),
             name: NSNotification.Name("PreferencesDidReset"),
             object: nil
         )
     }
     
     private func setupUI() {
         // Notifications Checkbox
         notificationsCheckbox = NSButton(checkboxWithTitle: "Enable Notifications", target: self, action: #selector(notificationsChanged))
         notificationsCheckbox.frame = NSRect(x: 20, y: 250, width: 200, height: 20)
         view.addSubview(notificationsCheckbox)
         
         // Status Label
         statusLabel = NSTextField(labelWithString: "")
         statusLabel.frame = NSRect(x: 20, y: 220, width: 440, height: 20)
         statusLabel.textColor = .secondaryLabelColor
         statusLabel.isEditable = false
         statusLabel.isBordered = false
         statusLabel.backgroundColor = .clear
         view.addSubview(statusLabel)
     }
     
     private func loadPreferences() {
         notificationsCheckbox.state = prefs.isNotificationsEnabled ? .on : .off
         updateStatusLabel()
     }
     
     private func updateStatusLabel() {
         statusLabel.stringValue = prefs.isNotificationsEnabled ?
             "Notifications are enabled for this app" :
             "Notifications are disabled"
     }
     
     @objc private func notificationsChanged() {
         prefs.isNotificationsEnabled = notificationsCheckbox.state == .on
         updateStatusLabel()
     }
     
     @objc private func preferencesDidReset() {
         loadPreferences()
     }
     
     deinit {
         NotificationCenter.default.removeObserver(self)
     }
 }


 // MARK: - App Delegate
 class AppDelegate: NSObject, NSApplicationDelegate {
     
     private var mainWindow: NSWindow!
     //private var preferencesWindowController: PreferencesWindowController?
     
     func applicationDidFinishLaunching(_ notification: Notification) {
         // Create main window
         mainWindow = NSWindow(
             contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
             styleMask: [.titled, .closable, .miniaturizable, .resizable],
             backing: .buffered,
             defer: false
         )
         mainWindow.title = "My App"
         mainWindow.center()
         
         let mainViewController = MainViewController()
         mainWindow.contentViewController = mainViewController
         mainWindow.makeKeyAndOrderFront(nil)
         
         setupMenu()
     }
     
     private func setupMenu() {
         let mainMenu = NSMenu()
         
         // App Menu
         let appMenuItem = NSMenuItem()
         mainMenu.addItem(appMenuItem)
         
         let appMenu = NSMenu()
         appMenuItem.submenu = appMenu
         
         appMenu.addItem(withTitle: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
         appMenu.addItem(NSMenuItem.separator())
         appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
         
         NSApplication.shared.mainMenu = mainMenu
     }
     
     // @objc func showPreferences() {
     //     if preferencesWindowController == nil {
     //         preferencesWindowController = PreferencesWindowController()
     //     }
     //     preferencesWindowController?.showWindow(nil)
     //     preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
     // }
 }

 // MARK: - Main View Controller
 class MainViewController: NSViewController {
     
     private let prefs = PreferencesManager.shared
     private var userNameLabel: NSTextField!
     private var themeLabel: NSTextField!
     private var darkModeLabel: NSTextField!
     private var notificationsLabel: NSTextField!
     private var preferencesButton: NSButton!
     
     override func loadView() {
         self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
     }
     
     override func viewDidLoad() {
         super.viewDidLoad()
         setupUI()
     }
     
     override func viewWillAppear() {
         super.viewWillAppear()
         updateLabels()
     }
     
     private func setupUI() {
         let stackView = NSStackView(frame: NSRect(x: 150, y: 150, width: 300, height: 150))
         stackView.orientation = .vertical
         stackView.spacing = 10
         stackView.alignment = .leading
         
         userNameLabel = NSTextField(labelWithString: "")
         themeLabel = NSTextField(labelWithString: "")
         darkModeLabel = NSTextField(labelWithString: "")
         notificationsLabel = NSTextField(labelWithString: "")
         
         stackView.addArrangedSubview(userNameLabel)
         stackView.addArrangedSubview(themeLabel)
         stackView.addArrangedSubview(darkModeLabel)
         stackView.addArrangedSubview(notificationsLabel)
         
         preferencesButton = NSButton(frame: NSRect(x: 0, y: 0, width: 150, height: 32))
         preferencesButton.title = "Open Preferences"
         preferencesButton.bezelStyle = .rounded
         preferencesButton.target = self
         preferencesButton.action = #selector(openPreferences)
         stackView.addArrangedSubview(preferencesButton)
         
         view.addSubview(stackView)
         
         updateLabels()
     }
     
     private func updateLabels() {
         let userName = prefs.userName.isEmpty ? "User" : prefs.userName
         userNameLabel.stringValue = "Hello, \(userName)!"
         themeLabel.stringValue = "Theme: \(prefs.selectedTheme)"
         darkModeLabel.stringValue = "Dark Mode: \(prefs.isDarkMode ? "On" : "Off")"
         notificationsLabel.stringValue = "Notifications: \(prefs.isNotificationsEnabled ? "Enabled" : "Disabled")"
     }
     
     @objc private func openPreferences() {
         if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
             appDelegate.showPreferences()
         }
     }
 }

 
 // MARK: - Main Entry Point
 let app = NSApplication.shared
 let delegate = AppDelegate()
 app.delegate = delegate
 app.run()
 
 */
