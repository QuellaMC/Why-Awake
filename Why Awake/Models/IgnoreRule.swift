import Foundation

public struct IgnoreRule: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var appName: String?
    public var assertionType: String?
    public var createdAt: Date

    public init(id: String? = nil, appName: String?, assertionType: String?, createdAt: Date = Date()) {
        self.appName = appName
        self.assertionType = assertionType
        self.createdAt = createdAt
        self.id = id ?? [
            appName?.lowercased() ?? "*",
            assertionType?.lowercased() ?? "*"
        ].joined(separator: "|")
    }

    public func matches(_ blocker: SleepBlocker) -> Bool {
        if let appName, appName.caseInsensitiveCompare(blocker.processName) != .orderedSame {
            return false
        }
        if let assertionType, assertionType.caseInsensitiveCompare(blocker.assertionType) != .orderedSame {
            return false
        }
        return appName != nil || assertionType != nil
    }
}
