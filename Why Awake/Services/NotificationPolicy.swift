import Foundation

public struct NotificationPolicy: Sendable {
    public var threshold: TimeInterval

    public init(threshold: TimeInterval) {
        self.threshold = threshold
    }

    public func candidates(from blockers: [SleepBlocker], ignoredIDs: Set<SleepBlocker.ID>) -> [SleepBlocker] {
        blockers.filter { blocker in
            blocker.ownerKind == .userApp
                && !blocker.isIgnored
                && !ignoredIDs.contains(blocker.id)
                && blocker.activeDuration >= threshold
        }
    }
}
