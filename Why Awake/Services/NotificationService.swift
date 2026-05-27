import Foundation
import UserNotifications

public protocol SleepBlockerNotifying {
    func requestAuthorization()
    func notifyLongRunningBlocker(_ blocker: SleepBlocker)
}

public struct UserNotificationService: SleepBlockerNotifying {
    public init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func notifyLongRunningBlocker(_ blocker: SleepBlocker) {
        let content = UNMutableNotificationContent()
        content.title = "\(blocker.processName) is keeping the Mac awake"
        content.body = "\(blocker.assertionType) has been active for \(blocker.durationText)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "long-blocker-\(blocker.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

public struct NoopNotificationService: SleepBlockerNotifying {
    public init() {}
    public func requestAuthorization() {}
    public func notifyLongRunningBlocker(_ blocker: SleepBlocker) {}
}
