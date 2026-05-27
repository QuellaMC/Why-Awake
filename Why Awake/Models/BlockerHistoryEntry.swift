import Foundation

public struct BlockerHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let processName: String
    public let assertionType: String
    public let reason: String
    public let category: SleepBlockerCategory
    public var firstSeen: Date
    public var lastSeen: Date
    public var occurrences: Int

    public init(
        id: String,
        processName: String,
        assertionType: String,
        reason: String,
        category: SleepBlockerCategory,
        firstSeen: Date,
        lastSeen: Date,
        occurrences: Int
    ) {
        self.id = id
        self.processName = processName
        self.assertionType = assertionType
        self.reason = reason
        self.category = category
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.occurrences = occurrences
    }

    public init(blocker: SleepBlocker, at date: Date) {
        self.init(
            id: Self.identity(for: blocker),
            processName: blocker.processName,
            assertionType: blocker.assertionType,
            reason: blocker.reason,
            category: blocker.category,
            firstSeen: date,
            lastSeen: date,
            occurrences: 1
        )
    }

    public static func identity(for blocker: SleepBlocker) -> String {
        [
            blocker.processName.lowercased(),
            blocker.assertionType.lowercased(),
            blocker.reason.lowercased()
        ].joined(separator: "|")
    }
}
