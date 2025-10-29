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
    
    // MARK: - Getters and Setters
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
        defaults.removeObject(forKey: Keys.isNotificationsEnabled)
        defaults.removeObject(forKey: Keys.defaultVideoDestination)
        defaults.removeObject(forKey: Keys.defaultAudioDestination)
    }
}

// MARK: - Preferences Window Controller
class PreferencesWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 632, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Preferences"
        window.center()
        
        self.init(window: window)
        
//        let preferencesViewController = PreferencesViewController()
        window.contentViewController = PreferencesViewController() //preferencesViewController
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
}

// MARK: - Preferences View Controller with Tab View
class PreferencesViewController: NSViewController  {
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
        notificationsTab.viewController = NotificationsPreferencesViewController()
        tabView.addTabViewItem(notificationsTab)
        
        view.addSubview(tabView)
    }
}

// MARK: - General Preferences View Controller
class GeneralPreferencesViewController: NSViewController, NSTextFieldDelegate {
    private let prefs = PreferencesManager.shared
    
    private enum PreferencesTextFieldTag: Int {
        case defaultVideoTextField = 1001
        case defaultAudioTextField = 1002
    }
    
    // UI Elements
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
        
        // Add observer for reset notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidReset),
            name: NSNotification.Name("PreferencesDidReset"),
            object: nil
        )
    }
    
    private func setupUI() {
        let containerView = NSView(frame: view.bounds)
        containerView.autoresizingMask = [.width, .height]
        view.addSubview(containerView)
        
        // Video Destination Label
        let videoLabel = NSTextField(labelWithString: "Video destination:")
        videoLabel.frame = NSRect(x: 20, y: 250, width: 110, height: 20)
        containerView.addSubview(videoLabel)
        
        // Video Destination Text Field
        defaultVideoDestinationField = NSTextField(frame: NSRect(x: 140, y: 248, width: 250, height: 24))
        defaultVideoDestinationField.tag = PreferencesTextFieldTag.defaultVideoTextField.rawValue
        defaultVideoDestinationField.placeholderString = "Path to folder"
        defaultVideoDestinationField.target = self
        defaultVideoDestinationField.action = #selector(videoDestinationChanged)
        containerView.addSubview(defaultVideoDestinationField)
        
        // Audio Destination Label
        let audioLabel = NSTextField(labelWithString: "Audio destination:")
        audioLabel.frame = NSRect(x: 20, y: 200, width: 110, height: 20)
        containerView.addSubview(audioLabel)
        
        // Audio Destination Text Field
        defaultAudioDestinationField = NSTextField(frame: NSRect(x: 140, y: 198, width: 250, height: 24))
        defaultAudioDestinationField.tag = PreferencesTextFieldTag.defaultAudioTextField.rawValue
        defaultAudioDestinationField.placeholderString = "Path to folder"
        defaultAudioDestinationField.target = self
        defaultAudioDestinationField.action = #selector(audioDestinationChanged)
        containerView.addSubview(defaultAudioDestinationField)
        
        // Reset Button
        resetButton = NSButton(frame: NSRect(x: 350, y: 20, width: 110, height: 32))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        containerView.addSubview(resetButton)
        
        // Set Delegates
        defaultAudioDestinationField.delegate = self
        defaultVideoDestinationField.delegate = self
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
    
    @objc private func preferencesDidReset() {
        loadPreferences()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: NSTextField Delegate methods
    func controlTextDidChange(_ obj: Notification) {
        let textField = obj.object as! NSTextField
        let currentValue = textField.stringValue
        
        // Convert tag to enum value for safer comparison
        guard let textFieldType = PreferencesTextFieldTag(rawValue: textField.tag) else {
            print("Unknown text field tag: \(textField.tag)")
            return
        }
        
        switch textFieldType {
            case .defaultVideoTextField:
                prefs.defaultVideoDestination = currentValue
                print("defaultVideoDestination changed to: \(currentValue)")
                break
            case .defaultAudioTextField:
                prefs.defaultAudioDestination = currentValue
                print("defaultAudioDestination changed to: \(currentValue)")
                break
        }
    }
}



// MARK: - Notifications Preferences View Controller
class NotificationsPreferencesViewController: NSViewController {
    private let prefs = PreferencesManager.shared
    
    // UI Elements
    private var notificationsCheckbox: NSButton!
    private var statusLabel: NSTextField!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPreferences()
    }
    
    private func setupUI() {
        let containerView = NSView(frame: view.bounds)
        containerView.autoresizingMask = [.width, .height]
        view.addSubview(containerView)
        
        // Notifications Checkbox
        notificationsCheckbox = NSButton(checkboxWithTitle: "Enable Notifications", target: self, action: #selector(notificationsChanged))
        notificationsCheckbox.frame = NSRect(x: 20, y: 250, width: 200, height: 20)
        containerView.addSubview(notificationsCheckbox)
        
        // Status Label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 20, y: 220, width: 440, height: 20)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        containerView.addSubview(statusLabel)
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
