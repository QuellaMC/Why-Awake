import Foundation

public struct AppLocalizer: Sendable {
    public let languagePreference: AppLanguagePreference

    public init(languagePreference: AppLanguagePreference = .system) {
        self.languagePreference = languagePreference
    }

    public var locale: Locale {
        if let localeIdentifier = languagePreference.localeIdentifier {
            return Locale(identifier: localeIdentifier)
        }
        return .autoupdatingCurrent
    }

    public func string(_ key: String) -> String {
        string(key, arguments: [])
    }

    public func string(_ key: String, _ arguments: CVarArg...) -> String {
        string(key, arguments: arguments)
    }

    public func string(_ key: String, arguments: [CVarArg]) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else {
            return format
        }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private var bundle: Bundle {
        guard let localizationCode = languagePreference.localizationCode,
              let path = Bundle.main.path(forResource: localizationCode, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }
}

public extension AppLanguagePreference {
    func displayName(localizedBy localizer: AppLocalizer) -> String {
        switch self {
        case .system:
            localizer.string("System")
        case .english:
            localizer.string("English")
        case .simplifiedChinese:
            localizer.string("Simplified Chinese")
        }
    }
}

public extension AppAppearancePreference {
    func displayName(localizedBy localizer: AppLocalizer) -> String {
        switch self {
        case .system:
            localizer.string("System")
        case .light:
            localizer.string("Light")
        case .dark:
            localizer.string("Dark")
        }
    }
}

public extension SleepBlockerCategory {
    func title(localizedBy localizer: AppLocalizer) -> String {
        switch self {
        case .displaySleep:
            localizer.string("Display sleep blockers")
        case .systemSleep:
            localizer.string("System sleep blockers")
        case .userActivity:
            localizer.string("User activity")
        case .externalMediaDevice:
            localizer.string("External media / devices")
        case .networkBackground:
            localizer.string("Network / background")
        case .other:
            localizer.string("Other assertions")
        }
    }
}

public extension SleepBlocker {
    func controlExplanation(localizedBy localizer: AppLocalizer) -> String {
        if ownerKind == .system {
            return localizer.string("This assertion is owned by macOS. Why Awake can show it, but cannot safely revoke it directly.")
        }

        return localizer.string("This assertion is owned by %@. Why Awake can open, quit, or force quit that app, but cannot revoke the assertion directly.", processName)
    }
}

public extension KeepAwakeMode {
    func displayName(localizedBy localizer: AppLocalizer) -> String {
        switch self {
        case .off:
            localizer.string("Off")
        case .display:
            localizer.string("Display awake")
        case .system:
            localizer.string("System awake")
        case .displayAndSystem:
            localizer.string("Display + system awake")
        }
    }
}

public extension KeepAwakeState {
    func displayName(localizedBy localizer: AppLocalizer) -> String {
        mode.displayName(localizedBy: localizer)
    }

    func explanation(localizedBy localizer: AppLocalizer) -> String {
        switch mode {
        case .off:
            localizer.string("Why Awake is not keeping the Mac awake.")
        case .display:
            localizer.string("Why Awake is keeping the display on.")
        case .system:
            localizer.string("Why Awake is preventing system sleep.")
        case .displayAndSystem:
            localizer.string("Why Awake is keeping the display on and preventing system sleep.")
        }
    }
}

public extension WhyAwakeSnapshot {
    func statusText(localizedBy localizer: AppLocalizer) -> String {
        if displayState == .blocked {
            return localizer.string("Display blocked")
        }
        if systemState == .blocked {
            return localizer.string("System sleep blocked")
        }
        return localizer.string("Nothing blocks display sleep")
    }

    func likelyDisplayExplanation(localizedBy localizer: AppLocalizer) -> String {
        guard let blocker = likelyDisplayBlocker else {
            return localizer.string("No app or system assertion is blocking display sleep.")
        }

        switch blocker.category {
        case .displaySleep:
            if blocker.ownerKind == .userApp {
                return localizer.string("%@ is directly preventing display sleep.", blocker.processName)
            }
            return localizer.string("macOS is delaying display sleep for %@.", blocker.reason)
        case .userActivity:
            return localizer.string("Recent user activity reset the idle timer, but it is not an app-owned blocker.")
        case .systemSleep:
            return localizer.string("%@ is preventing idle system sleep, which can keep the Mac awake.", blocker.processName)
        case .externalMediaDevice:
            return localizer.string("%@ is presenting an external media or device assertion.", blocker.processName)
        case .networkBackground:
            return localizer.string("%@ is active for network or background work.", blocker.processName)
        case .other:
            return localizer.string("%@ has an active power assertion.", blocker.processName)
        }
    }
}

public extension SleepBlockerKnowledge {
    static func categoryExplanation(for category: SleepBlockerCategory, localizedBy localizer: AppLocalizer) -> String {
        switch category {
        case .displaySleep:
            return localizer.string("This can keep the screen from turning off at the normal display idle timer.")
        case .systemSleep:
            return localizer.string("This can keep the whole Mac awake after the display would otherwise sleep.")
        case .userActivity:
            return localizer.string("This is recent keyboard, pointer, or HID input. It resets the idle timer, but it is not an app-owned blocker.")
        case .externalMediaDevice:
            return localizer.string("This usually comes from mounted storage, USB, Thunderbolt, or other device state. It is lower signal for display troubleshooting.")
        case .networkBackground:
            return localizer.string("This usually comes from network wake, push, sharing, or background service activity.")
        case .other:
            return localizer.string("macOS reported an assertion that does not map cleanly to a display or system sleep blocker.")
        }
    }

    static func assertionExplanation(for assertionType: String, localizedBy localizer: AppLocalizer) -> String {
        let normalized = assertionType.lowercased()

        if normalized == "preventuseridledisplaysleep" || normalized == "preventdisplaysleep" {
            return localizer.string("Prevents the display from sleeping while the assertion is active.")
        }
        if normalized == "internalpreventdisplaysleep" {
            return localizer.string("A macOS internal display-sleep delay. It often appears briefly while the system is counting down to turn the display off.")
        }
        if normalized == "preventuseridlesystemsleep" {
            return localizer.string("Prevents idle system sleep. The display may still turn off, but the Mac will not fully sleep while it is active.")
        }
        if normalized == "preventsystemsleep" || normalized == "noidlesleepassertion" {
            return localizer.string("Prevents system idle sleep. This is common during playback, calls, active downloads, or intentional keep-awake tools.")
        }
        if normalized == "userisactive" {
            return localizer.string("Recent user input reset the idle timer. This is normal activity, not something Why Awake should quit or revoke.")
        }
        if normalized == "externalmedia" || normalized == "usb" || normalized == "thndr" {
            return localizer.string("A device or mounted-media assertion. It can affect sleep behavior, but is usually not the reason the display stays awake.")
        }
        if normalized == "networkclientactive" || normalized == "magicwake" {
            return localizer.string("Network activity can wake or keep parts of the system ready for background work.")
        }
        if normalized == "backgroundtask" || normalized == "applepushservicetask" {
            return localizer.string("A background task assertion. It is usually temporary and owned by macOS or an app service.")
        }

        return localizer.string("A macOS power assertion. The owning process controls when this assertion is released.")
    }

    static func commonBlockerExplanation(for blocker: SleepBlocker, localizedBy localizer: AppLocalizer) -> String? {
        let process = blocker.processName.lowercased()
        let reason = blocker.reason.lowercased()
        let assertion = blocker.assertionType.lowercased()

        if process == "amphetamine" {
            return localizer.string("Amphetamine intentionally creates keep-awake sessions. End the session in Amphetamine if it is no longer wanted.")
        }
        if process == "caffeinate" {
            return localizer.string("The caffeinate command-line tool is intentionally keeping the Mac awake until that command exits.")
        }
        if process == "zoom" || process == "facetime" || reason.contains("video") || reason.contains("call") {
            return localizer.string("Calls and screen sharing commonly prevent display or system sleep during an active session.")
        }
        if process == "music" || process == "spotify" || process == "coreaudiod" || reason.contains("audio") {
            return localizer.string("Audio playback commonly keeps system sleep from starting so playback does not stop unexpectedly.")
        }
        if process == "powerd" && reason.contains("delaydisplayoff") {
            return localizer.string("powerd is showing macOS's own short display-off delay. It is treated as context, not a user-app blocker.")
        }
        if process == "powerd" && reason.contains("prevent sleep while display is on") {
            return localizer.string("powerd is reflecting the normal rule that the Mac should not idle-sleep while the display is still awake.")
        }
        if process == "powerd" && reason.contains("externalmedia") {
            return localizer.string("macOS detected mounted external media. Ejecting unused disks can remove this assertion, but it is hidden by default because it is often unrelated to display sleep.")
        }
        if process == "windowserver" && assertion == "userisactive" {
            return localizer.string("WindowServer reports recent input events. This resets the timer, but there is no app to quit.")
        }
        if process == "backupd" {
            return localizer.string("Time Machine backup activity can temporarily delay system sleep.")
        }
        if process == "sharingd" {
            return localizer.string("Sharing services such as AirDrop, Handoff, or local network sharing can create temporary background assertions.")
        }
        if process == "mds" || process == "mds_stores" {
            return localizer.string("Spotlight indexing can create temporary background work after file changes or new storage is attached.")
        }
        if reason.contains("electron") {
            return localizer.string("Electron apps sometimes use a generic no-idle-sleep assertion. The app shown here owns the assertion.")
        }

        return nil
    }
}

public extension AppActionPolicy {
    static func explanation(for blocker: SleepBlocker, localizedBy localizer: AppLocalizer) -> String {
        if blocker.ownerKind == .system {
            return localizer.string("This assertion is owned by macOS. Why Awake can explain it, but does not kill system processes by default.")
        }

        return localizer.string("Why Awake cannot directly revoke another app's assertion. Use the owning app's controls, quit it, or force quit only if normal quit fails.")
    }
}
