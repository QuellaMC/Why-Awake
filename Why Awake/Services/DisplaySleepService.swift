import Foundation

public protocol DisplaySleepServicing: Sendable {
    func sleepDisplayNow(localizer: AppLocalizer) async -> AppActionResult
}

public struct PMSetDisplaySleepService: DisplaySleepServicing {
    private let runner: CommandRunning

    public init(runner: CommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    public func sleepDisplayNow(localizer: AppLocalizer) async -> AppActionResult {
        do {
            _ = try await runner.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["displaysleepnow"])
            return .success(localizer.string("Asked macOS to sleep the display."))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
