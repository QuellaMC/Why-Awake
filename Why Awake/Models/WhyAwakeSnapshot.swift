import Foundation

public enum SleepCapabilityState: String, Codable, Hashable, Sendable {
    case canSleep
    case blocked

    public var title: String {
        switch self {
        case .canSleep:
            "Can sleep"
        case .blocked:
            "Blocked"
        }
    }
}

public struct WhyAwakeSnapshot: Equatable, Sendable {
    public let generatedAt: Date
    public let activeAssertionTypes: Set<String>
    public let blockers: [SleepBlocker]

    public init(generatedAt: Date, activeAssertionTypes: Set<String>, blockers: [SleepBlocker]) {
        self.generatedAt = generatedAt
        self.activeAssertionTypes = activeAssertionTypes
        self.blockers = blockers
    }

    public static let empty = WhyAwakeSnapshot(generatedAt: Date(), activeAssertionTypes: [], blockers: [])

    public var displayState: SleepCapabilityState {
        if blockers.contains(where: { !$0.isIgnored && $0.isPrimaryBlocker && $0.category == .displaySleep }) {
            return .blocked
        }
        if !blockers.contains(where: { Self.isDisplayBlockingAssertion($0.assertionType) })
            && activeAssertionTypes.contains(where: Self.isDisplayBlockingAssertion) {
            return .blocked
        }
        return .canSleep
    }

    public var systemState: SleepCapabilityState {
        if blockers.contains(where: { !$0.isIgnored && $0.isPrimaryBlocker && $0.category == .systemSleep }) {
            return .blocked
        }
        if !blockers.contains(where: { Self.isSystemBlockingAssertion($0.assertionType) })
            && activeAssertionTypes.contains(where: Self.isSystemBlockingAssertion) {
            return .blocked
        }
        return .canSleep
    }

    public var statusText: String {
        if displayState == .blocked {
            return "Display blocked"
        }
        if systemState == .blocked {
            return "System sleep blocked"
        }
        return "Nothing blocks display sleep"
    }

    public var visibleBlockers: [SleepBlocker] {
        blockers.sorted { lhs, rhs in
            if lhs.isIgnored != rhs.isIgnored {
                return !lhs.isIgnored
            }
            if lhs.category != rhs.category {
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
            if lhs.activeDuration != rhs.activeDuration {
                return lhs.activeDuration > rhs.activeDuration
            }
            return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending
        }
    }

    public var likelyDisplayBlocker: SleepBlocker? {
        primaryBlockers
            .filter { !$0.isIgnored }
            .compactMap { blocker -> (SleepBlocker, Int)? in
                guard let priority = Self.displayPriority(for: blocker) else { return nil }
                return (blocker, priority)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }
                return lhs.0.activeDuration > rhs.0.activeDuration
            }
            .first?
            .0
    }

    public var likelyDisplayExplanation: String {
        guard let blocker = likelyDisplayBlocker else {
            return "No app or system assertion is blocking display sleep."
        }

        switch blocker.category {
        case .displaySleep:
            if blocker.ownerKind == .userApp {
                return "\(blocker.processName) is directly preventing display sleep."
            }
            return "macOS is delaying display sleep for \(blocker.reason)."
        case .userActivity:
            return "Recent user activity reset the idle timer, but it is not an app-owned blocker."
        case .systemSleep:
            return "\(blocker.processName) is preventing idle system sleep, which can keep the Mac awake."
        case .externalMediaDevice:
            return "\(blocker.processName) is presenting an external media or device assertion."
        case .networkBackground:
            return "\(blocker.processName) is active for network or background work."
        case .other:
            return "\(blocker.processName) has an active power assertion."
        }
    }

    public var primaryBlockers: [SleepBlocker] {
        visibleBlockers.filter(\.isPrimaryBlocker)
    }

    public var secondaryBlockers: [SleepBlocker] {
        visibleBlockers.filter(\.isLowerSignal)
    }

    public var hasRecentUserActivity: Bool {
        blockers.contains { !$0.isIgnored && $0.category == .userActivity }
            || activeAssertionTypes.contains { $0.caseInsensitiveCompare("UserIsActive") == .orderedSame }
    }

    public func applyingIgnoreRules(_ rules: [IgnoreRule]) -> WhyAwakeSnapshot {
        let updated = blockers.map { blocker in
            blocker.with(isIgnored: rules.contains { $0.matches(blocker) })
        }
        return WhyAwakeSnapshot(generatedAt: generatedAt, activeAssertionTypes: activeAssertionTypes, blockers: updated)
    }

    private static func isDisplayBlockingAssertion(_ type: String) -> Bool {
        let normalized = type.lowercased()
        return normalized == "preventuseridledisplaysleep"
            || normalized == "internalpreventdisplaysleep"
            || normalized == "preventdisplaysleep"
    }

    private static func isSystemBlockingAssertion(_ type: String) -> Bool {
        let normalized = type.lowercased()
        return normalized == "preventsystemsleep"
            || normalized == "preventuseridlesystemsleep"
            || normalized == "noidlesleepassertion"
    }

    private static func displayPriority(for blocker: SleepBlocker) -> Int? {
        switch blocker.category {
        case .displaySleep where blocker.ownerKind == .userApp:
            0
        case .displaySleep:
            2
        case .systemSleep where blocker.assertionType.localizedCaseInsensitiveContains("NoIdleSleep"):
            3
        default:
            nil
        }
    }
}

private extension SleepBlockerCategory {
    var sortOrder: Int {
        switch self {
        case .displaySleep:
            0
        case .systemSleep:
            1
        case .userActivity:
            2
        case .externalMediaDevice:
            3
        case .networkBackground:
            4
        case .other:
            5
        }
    }
}
