import Cocoa
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusBar = NSStatusBar()
    lazy var statusItem = statusBar.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
    
    let network = NetworkQuality()
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = statusItem.button else { fatalError("status bar didn't have button?") }
        
        statusItem.menu = NSMenu()
        statusItem.menu!.items = [NSMenuItem(title: "Quit", action: #selector(tappedQuit), keyEquivalent: "q")]
                
        network.display
            .receive(on: RunLoop.main)
            .sink { [weak menuBarButton] in
                menuBarButton?.title = $0
            }
            .store(in: &cancellables)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc private func tappedQuit() {
        exit(0)
    }
}

