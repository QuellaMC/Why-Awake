import Foundation

public enum SleepBlockerCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case displaySleep
    case systemSleep
    case userActivity
    case externalMediaDevice
    case networkBackground
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .displaySleep:
            "Display sleep blockers"
        case .systemSleep:
            "System sleep blockers"
        case .userActivity:
            "User activity"
        case .externalMediaDevice:
            "External media / devices"
        case .networkBackground:
            "Network / background"
        case .other:
            "Other assertions"
        }
    }

    public var symbolName: String {
        switch self {
        case .displaySleep:
            "display"
        case .systemSleep:
            "moon.zzz"
        case .userActivity:
            "cursorarrow.click"
        case .externalMediaDevice:
            "externaldrive"
        case .networkBackground:
            "network"
        case .other:
            "questionmark.circle"
        }
    }
}

public enum SleepBlockerOwnerKind: String, Codable, Hashable, Sendable {
    case userApp
    case system
}

public enum SleepBlockerSource: String, Codable, Hashable, Sendable {
    case process
    case kernel
}

public struct SleepBlocker: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let processName: String
    public let pid: Int?
    public let assertionType: String
    public let reason: String
    public let activeDuration: TimeInterval
    public let category: SleepBlockerCategory
    public let ownerKind: SleepBlockerOwnerKind
    public let source: SleepBlockerSource
    public let isIgnored: Bool

    public init(
        id: String? = nil,
        processName: String,
        pid: Int?,
        assertionType: String,
        reason: String,
        activeDuration: TimeInterval,
        category: SleepBlockerCategory,
        ownerKind: SleepBlockerOwnerKind,
        source: SleepBlockerSource,
        isIgnored: Bool = false
    ) {
        self.processName = processName
        self.pid = pid
        self.assertionType = assertionType
        self.reason = reason
        self.activeDuration = activeDuration
        self.category = category
        self.ownerKind = ownerKind
        self.source = source
        self.isIgnored = isIgnored
        self.id = id ?? SleepBlocker.makeID(
            processName: processName,
            pid: pid,
            assertionType: assertionType,
            reason: reason,
            source: source
        )
    }

    public func with(
        processName: String? = nil,
        pid: Int? = nil,
        assertionType: String? = nil,
        reason: String? = nil,
        activeDuration: TimeInterval? = nil,
        category: SleepBlockerCategory? = nil,
        ownerKind: SleepBlockerOwnerKind? = nil,
        source: SleepBlockerSource? = nil,
        isIgnored: Bool? = nil
    ) -> SleepBlocker {
        SleepBlocker(
            processName: processName ?? self.processName,
            pid: pid ?? self.pid,
            assertionType: assertionType ?? self.assertionType,
            reason: reason ?? self.reason,
            activeDuration: activeDuration ?? self.activeDuration,
            category: category ?? self.category,
            ownerKind: ownerKind ?? self.ownerKind,
            source: source ?? self.source,
            isIgnored: isIgnored ?? self.isIgnored
        )
    }

    public var durationText: String {
        DurationFormatter.short.string(from: activeDuration) ?? "0s"
    }

    public var pidText: String {
        pid.map(String.init) ?? "-"
    }

    public var controlExplanation: String {
        if ownerKind == .system {
            return "This assertion is owned by macOS. Why Awake can show it, but cannot safely revoke it directly."
        }

        return "This assertion is owned by \(processName). Why Awake can open, quit, or force quit that app, but cannot revoke the assertion directly."
    }

    public var isLowerSignal: Bool {
        SleepBlockerKnowledge.isLowerSignal(self)
    }

    public var isPrimaryBlocker: Bool {
        !isLowerSignal && (category == .displaySleep || category == .systemSleep)
    }

    private static func makeID(
        processName: String,
        pid: Int?,
        assertionType: String,
        reason: String,
        source: SleepBlockerSource
    ) -> String {
        [
            source.rawValue,
            processName.lowercased(),
            pid.map(String.init) ?? "kernel",
            assertionType.lowercased(),
            reason.lowercased()
        ].joined(separator: "|")
    }
}

public enum DurationFormatter {
    public static let short: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropLeading]
        return formatter
    }()
}
