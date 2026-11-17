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
