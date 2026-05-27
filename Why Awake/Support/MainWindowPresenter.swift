import AppKit

@MainActor
enum MainWindowPresenter {
    @discardableResult
    static func activateExistingMainWindow() -> Bool {
        guard let window = NSApp.windows.first(where: { $0.title == "Why Awake" }) else {
            return false
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
