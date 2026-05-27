import Foundation

public enum SleepBlockerKnowledge {
    public static func categoryExplanation(for category: SleepBlockerCategory) -> String {
        switch category {
        case .displaySleep:
            return "This can keep the screen from turning off at the normal display idle timer."
        case .systemSleep:
            return "This can keep the whole Mac awake after the display would otherwise sleep."
        case .userActivity:
            return "This is recent keyboard, pointer, or HID input. It resets the idle timer, but it is not an app-owned blocker."
        case .externalMediaDevice:
            return "This usually comes from mounted storage, USB, Thunderbolt, or other device state. It is lower signal for display troubleshooting."
        case .networkBackground:
            return "This usually comes from network wake, push, sharing, or background service activity."
        case .other:
            return "macOS reported an assertion that does not map cleanly to a display or system sleep blocker."
        }
    }

    public static func assertionExplanation(for assertionType: String) -> String {
        let normalized = assertionType.lowercased()

        if normalized == "preventuseridledisplaysleep" || normalized == "preventdisplaysleep" {
            return "Prevents the display from sleeping while the assertion is active."
        }
        if normalized == "internalpreventdisplaysleep" {
            return "A macOS internal display-sleep delay. It often appears briefly while the system is counting down to turn the display off."
        }
        if normalized == "preventuseridlesystemsleep" {
            return "Prevents idle system sleep. The display may still turn off, but the Mac will not fully sleep while it is active."
        }
        if normalized == "preventsystemsleep" || normalized == "noidlesleepassertion" {
            return "Prevents system idle sleep. This is common during playback, calls, active downloads, or intentional keep-awake tools."
        }
        if normalized == "userisactive" {
            return "Recent user input reset the idle timer. This is normal activity, not something Why Awake should quit or revoke."
        }
        if normalized == "externalmedia" || normalized == "usb" || normalized == "thndr" {
            return "A device or mounted-media assertion. It can affect sleep behavior, but is usually not the reason the display stays awake."
        }
        if normalized == "networkclientactive" || normalized == "magicwake" {
            return "Network activity can wake or keep parts of the system ready for background work."
        }
        if normalized == "backgroundtask" || normalized == "applepushservicetask" {
            return "A background task assertion. It is usually temporary and owned by macOS or an app service."
        }

        return "A macOS power assertion. The owning process controls when this assertion is released."
    }

    public static func commonBlockerExplanation(for blocker: SleepBlocker) -> String? {
        let process = blocker.processName.lowercased()
        let reason = blocker.reason.lowercased()
        let assertion = blocker.assertionType.lowercased()

        if process == "amphetamine" {
            return "Amphetamine intentionally creates keep-awake sessions. End the session in Amphetamine if it is no longer wanted."
        }
        if process == "caffeinate" {
            return "The caffeinate command-line tool is intentionally keeping the Mac awake until that command exits."
        }
        if process == "zoom" || process == "facetime" || reason.contains("video") || reason.contains("call") {
            return "Calls and screen sharing commonly prevent display or system sleep during an active session."
        }
        if process == "music" || process == "spotify" || process == "coreaudiod" || reason.contains("audio") {
            return "Audio playback commonly keeps system sleep from starting so playback does not stop unexpectedly."
        }
        if process == "powerd" && reason.contains("delaydisplayoff") {
            return "powerd is showing macOS's own short display-off delay. It is treated as context, not a user-app blocker."
        }
        if process == "powerd" && reason.contains("prevent sleep while display is on") {
            return "powerd is reflecting the normal rule that the Mac should not idle-sleep while the display is still awake."
        }
        if process == "powerd" && reason.contains("externalmedia") {
            return "macOS detected mounted external media. Ejecting unused disks can remove this assertion, but it is hidden by default because it is often unrelated to display sleep."
        }
        if process == "windowserver" && assertion == "userisactive" {
            return "WindowServer reports recent input events. This resets the timer, but there is no app to quit."
        }
        if process == "backupd" {
            return "Time Machine backup activity can temporarily delay system sleep."
        }
        if process == "sharingd" {
            return "Sharing services such as AirDrop, Handoff, or local network sharing can create temporary background assertions."
        }
        if process == "mds" || process == "mds_stores" {
            return "Spotlight indexing can create temporary background work after file changes or new storage is attached."
        }
        if reason.contains("electron") {
            return "Electron apps sometimes use a generic no-idle-sleep assertion. The app shown here owns the assertion."
        }

        return nil
    }

    public static func isLowerSignal(_ blocker: SleepBlocker) -> Bool {
        switch blocker.category {
        case .userActivity, .externalMediaDevice, .networkBackground, .other:
            return true
        case .displaySleep, .systemSleep:
            return isKnownTransientSystemAssertion(blocker)
        }
    }

    private static func isKnownTransientSystemAssertion(_ blocker: SleepBlocker) -> Bool {
        let process = blocker.processName.lowercased()
        let reason = blocker.reason.lowercased()
        guard blocker.ownerKind == .system || process == "powerd" || process == "windowserver" else {
            return false
        }

        return process == "windowserver"
            || reason.contains("delaydisplayoff")
            || reason.contains("prevent sleep while display is on")
            || reason.contains("externalmedia")
    }
}
