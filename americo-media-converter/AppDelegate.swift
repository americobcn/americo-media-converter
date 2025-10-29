import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    private var preferencesWindowController: PreferencesWindowController?
        
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.window.title = "Américo's Media Converter"
        window.maxSize.width = 1920
        window.maxSize.height = 1055
        window.minSize.width = 1920
        window.minSize.height = 1055

    }
    
    @objc func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
    }
        
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

}
