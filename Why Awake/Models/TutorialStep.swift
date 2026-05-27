import Foundation

public enum TutorialStep: String, CaseIterable, Identifiable, Sendable {
    case sleepStatus
    case keepAwakeControls
    case blockersList
    case blockerDetails
    case safeActions
    case liveControls
    case menuBar
    case settings

    public var id: String { rawValue }

    public var targetRegion: TutorialTargetRegion {
        switch self {
        case .sleepStatus:
            .statusCards
        case .keepAwakeControls:
            .keepAwakeCard
        case .blockersList:
            .blockersList
        case .blockerDetails:
            .detailInspector
        case .safeActions:
            .detailActions
        case .liveControls:
            .toolbar
        case .menuBar:
            .menuBarExtra
        case .settings:
            .settings
        }
    }

    public func title(localizedBy localizer: AppLocalizer) -> String {
        switch self {
        case .sleepStatus:
            localizer.string("Tutorial: Display vs system sleep")
        case .keepAwakeControls:
            localizer.string("Tutorial: Why Awake controls")
        case .blockersList:
            localizer.string("Tutorial: Blockers list")
        case .blockerDetails:
            localizer.string("Tutorial: Details and explanations")
        case .safeActions:
            localizer.string("Tutorial: Safe app actions")
        case .liveControls:
            localizer.string("Tutorial: Live controls")
        case .menuBar:
            localizer.string("Tutorial: Menu bar controls")
        case .settings:
            localizer.string("Tutorial: Settings")
        }
    }

    public func body(localizedBy localizer: AppLocalizer, hasVisibleBlockers: Bool) -> String {
        switch self {
        case .sleepStatus:
            return localizer.string("The top cards separate display sleep from whole-Mac system sleep, so you can tell whether the screen, the Mac, or both are being kept awake.")
        case .keepAwakeControls:
            return localizer.string("These toggles create assertions owned by Why Awake. They are for intentionally keeping your Mac awake and are separate from assertions owned by other apps.")
        case .blockersList:
            if hasVisibleBlockers {
                return localizer.string("The list groups current blockers by cause. Rows show the app or system owner, duration, assertion type, badges, and a filter for lower-signal context.")
            }
            return localizer.string("No blockers are shown right now. When one appears, this list groups it by cause and shows the owner, duration, assertion type, badges, and lower-signal context filter.")
        case .blockerDetails:
            return localizer.string("Use Summary for the important facts, Why for plain-language meaning, and Technical for the raw assertion details from macOS.")
        case .safeActions:
            return localizer.string("Why Awake can open, quit, or explicitly force quit the owning user app when safe. It cannot directly revoke another app's assertion, and it does not kill system processes by default.")
        case .liveControls:
            return localizer.string("Refresh reads the current macOS power state now. Pause stops automatic refreshes. Turn Display Off asks macOS to sleep the display without revoking any other app's assertion.")
        case .menuBar:
            return localizer.string("The menu bar item gives quick access to blockers, display sleep, monitoring, keep-awake controls, and this tutorial without keeping the main window in front.")
        case .settings:
            return localizer.string("Settings control refresh interval, language, appearance, monitoring, and Why Awake's own keep-awake preferences.")
        }
    }
}

public enum TutorialTargetRegion: Hashable, Sendable {
    case statusCards
    case keepAwakeCard
    case blockersList
    case detailInspector
    case detailActions
    case toolbar
    case menuBarExtra
    case settings
}
