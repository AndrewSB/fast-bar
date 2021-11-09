import Cocoa
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusBar = NSStatusBar()
    lazy var statusItem = statusBar.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
    
    let network = NetworkQuality()
    private var cancellables = Set<AnyCancellable>()
    
    private var timeAgo = Date()
    private lazy var timeAgoRenderTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [unowned self] _ in
        self.timeAgoMenuItem.title = "⌛️ \(relativeTimeFormatter.localizedString(for: timeAgo, relativeTo: Date()))"
        setMenuItems()
    })
    private var timeAgoMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = statusItem.button else { fatalError("status bar didn't have button?") }
        
        statusItem.menu = NSMenu()
        setMenuItems()

        network.display
            .receive(on: RunLoop.main)
            .sink { [weak self, weak menuBarButton] in
                self?.timeAgo = Date()
                menuBarButton?.title = $0
            }
            .store(in: &cancellables)
        
        timeAgoRenderTimer.tolerance = 0.5
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc private func tappedRefresh() {
        network.forceRefresh()
    }

    @objc private func tappedQuit() {
        exit(0)
    }

    private func setMenuItems() {
        statusItem.menu!.items = [
            timeAgoMenuItem,
            NSMenuItem(title: "Refresh", action: #selector(tappedRefresh), keyEquivalent: "r"),
            NSMenuItem(title: "Quit", action: #selector(tappedQuit), keyEquivalent: "q")
        ]
    }
}

let relativeTimeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.formattingContext = .standalone
    return f
}()
