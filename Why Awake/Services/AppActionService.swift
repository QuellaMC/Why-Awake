import AppKit
import Foundation

public protocol AppActionServicing {
    func open(_ blocker: SleepBlocker, localizer: AppLocalizer) -> AppActionResult
    func quit(_ blocker: SleepBlocker, localizer: AppLocalizer) -> AppActionResult
    func forceQuit(_ blocker: SleepBlocker, localizer: AppLocalizer) -> AppActionResult
}

public struct MacAppActionService: AppActionServicing {
    public init() {}

    public func open(_ blocker: SleepBlocker, localizer: AppLocalizer) -> AppActionResult {
        guard AppActionPolicy.canOpen(blocker), let app = runningApplication(for: blocker) else {
            return .blocked(localizer.string("Why Awake could not safely match a running app for %@.", blocker.processName))
        }

        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        return .success(localizer.string("Opened %@.", blocker.processName))
    }

    public func quit(_ blocker: SleepBlocker, localizer: AppLocalizer) -> AppActionResult {
        guard AppActionPolicy.canQuit(blocker), let app = runningApplication(for: blocker) else {
            return .blocked(AppActionPolicy.explanation(for: blocker, localizedBy: localizer))
        }

        return app.terminate()
            ? .success(localizer.string("Asked %@ to quit.", blocker.processName))
            : .failed(localizer.string("%@ did not accept the quit request.", blocker.processName))
    }

    public func forceQuit(_ blocker: SleepBlocker, localizer: AppLocalizer) -> AppActionResult {
        guard AppActionPolicy.canForceQuit(blocker), let app = runningApplication(for: blocker) else {
            return .blocked(AppActionPolicy.explanation(for: blocker, localizedBy: localizer))
        }

        return app.forceTerminate()
            ? .success(localizer.string("Force quit %@.", blocker.processName))
            : .failed(localizer.string("Could not force quit %@.", blocker.processName))
    }

    private func runningApplication(for blocker: SleepBlocker) -> NSRunningApplication? {
        guard let pid = blocker.pid,
              let app = NSRunningApplication(processIdentifier: pid_t(pid)),
              AppActionPolicy.matchesRunningApplicationName(
                blocker.processName,
                localizedName: app.localizedName,
                bundleURL: app.bundleURL,
                executableURL: app.executableURL
              )
        else {
            return nil
        }
        return app
    }
}
