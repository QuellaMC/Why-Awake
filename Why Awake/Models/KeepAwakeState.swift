import Foundation

public enum KeepAwakeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case display
    case system
    case displayAndSystem

    public var id: String { rawValue }

    public init(displayAwake: Bool, systemAwake: Bool) {
        switch (displayAwake, systemAwake) {
        case (false, false):
            self = .off
        case (true, false):
            self = .display
        case (false, true):
            self = .system
        case (true, true):
            self = .displayAndSystem
        }
    }

    public var displayName: String {
        switch self {
        case .off:
            "Off"
        case .display:
            "Display awake"
        case .system:
            "System awake"
        case .displayAndSystem:
            "Display + system awake"
        }
    }

    public var keepsDisplayAwake: Bool {
        self == .display || self == .displayAndSystem
    }

    public var keepsSystemAwake: Bool {
        self == .system || self == .displayAndSystem
    }
}

public struct KeepAwakeState: Equatable, Sendable {
    public var mode: KeepAwakeMode
    public var assertionName: String

    public init(mode: KeepAwakeMode = .off, assertionName: String = "Why Awake keep awake") {
        self.mode = mode
        self.assertionName = assertionName
    }

    public var isEnabled: Bool {
        mode != .off
    }

    public var displayName: String {
        mode.displayName
    }

    public var keepsDisplayAwake: Bool {
        mode.keepsDisplayAwake
    }

    public var keepsSystemAwake: Bool {
        mode.keepsSystemAwake
    }

    public var explanation: String {
        switch mode {
        case .off:
            return "Why Awake is not keeping the Mac awake."
        case .display:
            return "Why Awake is keeping the display on."
        case .system:
            return "Why Awake is preventing system sleep."
        case .displayAndSystem:
            return "Why Awake is keeping the display on and preventing system sleep."
        }
    }
}
