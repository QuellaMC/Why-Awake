import Foundation

public enum AppActionPolicy {
    public static func canOpen(_ blocker: SleepBlocker) -> Bool {
        blocker.pid != nil && blocker.source == .process && blocker.ownerKind == .userApp
    }

    public static func canQuit(_ blocker: SleepBlocker) -> Bool {
        canOpen(blocker)
    }

    public static func canForceQuit(_ blocker: SleepBlocker) -> Bool {
        canQuit(blocker)
    }

    public static func explanation(for blocker: SleepBlocker) -> String {
        if blocker.ownerKind == .system {
            return "This assertion is owned by macOS. Why Awake can explain it, but does not kill system processes by default."
        }

        return "Why Awake cannot directly revoke another app's assertion. Use the owning app's controls, quit it, or force quit only if normal quit fails."
    }

    public static func matchesRunningApplicationName(
        _ expectedName: String,
        localizedName: String?,
        bundleURL: URL?,
        executableURL: URL?
    ) -> Bool {
        let candidates = [
            localizedName,
            bundleURL?.deletingPathExtension().lastPathComponent,
            executableURL?.lastPathComponent
        ]
        return candidates.contains { candidate in
            candidate?.caseInsensitiveCompare(expectedName) == .orderedSame
        }
    }
}

public enum AppActionResult: Equatable, Sendable {
    case success(String)
    case blocked(String)
    case failed(String)

    public var message: String {
        switch self {
        case .success(let message), .blocked(let message), .failed(let message):
            message
        }
    }
}
