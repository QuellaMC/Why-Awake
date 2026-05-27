import Foundation

public enum PowerSource: String, Equatable, Sendable {
    case battery
    case powerAdapter
    case unknown
}

public struct PowerSettings: Equatable, Sendable {
    public let displaySleepMinutes: Int?
    public let systemSleepMinutes: Int?
    public let hidIdleSeconds: TimeInterval?
    public let activePowerSource: PowerSource

    public init(
        displaySleepMinutes: Int? = nil,
        systemSleepMinutes: Int? = nil,
        hidIdleSeconds: TimeInterval? = nil,
        activePowerSource: PowerSource = .unknown
    ) {
        self.displaySleepMinutes = displaySleepMinutes
        self.systemSleepMinutes = systemSleepMinutes
        self.hidIdleSeconds = hidIdleSeconds
        self.activePowerSource = activePowerSource
    }

    public static let unknown = PowerSettings()

    public var displaySleepRemaining: TimeInterval? {
        remainingSeconds(for: displaySleepMinutes)
    }

    public var systemSleepRemaining: TimeInterval? {
        remainingSeconds(for: systemSleepMinutes)
    }

    private func remainingSeconds(for timerMinutes: Int?) -> TimeInterval? {
        guard let timerMinutes, timerMinutes > 0, let hidIdleSeconds else {
            return nil
        }
        return max(TimeInterval(timerMinutes * 60) - hidIdleSeconds, 0)
    }
}
