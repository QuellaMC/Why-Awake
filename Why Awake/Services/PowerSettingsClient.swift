import Foundation

public protocol PowerSettingsReading: Sendable {
    func settings() async throws -> PowerSettings
}

public struct PMSetPowerSettingsClient: PowerSettingsReading {
    private let runner: CommandRunning
    private let parser: PowerSettingsParser

    public init(runner: CommandRunning = ProcessCommandRunner(), parser: PowerSettingsParser = PowerSettingsParser()) {
        self.runner = runner
        self.parser = parser
    }

    public func settings() async throws -> PowerSettings {
        async let pmsetOutput = runner.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["-g", "custom"])
        async let powerSourceOutput = runner.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["-g", "ps"])
        async let ioregOutput = runner.run(URL(fileURLWithPath: "/usr/sbin/ioreg"), arguments: ["-c", "IOHIDSystem", "-r"])
        return try await parser.parse(
            pmsetOutput: pmsetOutput,
            ioregOutput: ioregOutput,
            powerSourceOutput: powerSourceOutput
        )
    }
}

public struct StaticPowerSettingsClient: PowerSettingsReading {
    public var currentSettings: PowerSettings

    public init(_ settings: PowerSettings) {
        currentSettings = settings
    }

    public func settings() async throws -> PowerSettings {
        currentSettings
    }
}

public struct PowerSettingsParser: Sendable {
    public init() {}

    public func parse(pmsetOutput: String, ioregOutput: String, powerSourceOutput: String = "") -> PowerSettings {
        let activePowerSource = activePowerSource(in: powerSourceOutput)
        let timerSections = timerSections(in: pmsetOutput)

        return PowerSettings(
            displaySleepMinutes: timer(named: "displaysleep", powerSource: activePowerSource, sections: timerSections),
            systemSleepMinutes: timer(named: "sleep", powerSource: activePowerSource, sections: timerSections),
            hidIdleSeconds: hidIdleSeconds(in: ioregOutput),
            activePowerSource: activePowerSource
        )
    }

    private func activePowerSource(in output: String) -> PowerSource {
        let normalized = output.lowercased()
        if normalized.contains("battery power") {
            return .battery
        }
        if normalized.contains("ac power") || normalized.contains("power adapter") {
            return .powerAdapter
        }
        return .unknown
    }

    private func timer(named name: String, powerSource: PowerSource, sections: TimerSections) -> Int? {
        if let value = sections.values[powerSource]?[name] {
            return value
        }

        switch powerSource {
        case .battery:
            return sections.values[.powerAdapter]?[name] ?? sections.firstValues[name]
        case .powerAdapter:
            return sections.values[.battery]?[name] ?? sections.firstValues[name]
        case .unknown:
            return sections.firstValues[name]
        }
    }

    private func timerSections(in output: String) -> TimerSections {
        var currentSource = PowerSource.unknown
        var values: [PowerSource: [String: Int]] = [:]
        var firstValues: [String: Int] = [:]

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.caseInsensitiveCompare("Battery Power:") == .orderedSame {
                currentSource = .battery
                continue
            }
            if trimmed.caseInsensitiveCompare("AC Power:") == .orderedSame {
                currentSource = .powerAdapter
                continue
            }

            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2, let value = Int(parts[1]) else {
                continue
            }

            let name = String(parts[0])
            values[currentSource, default: [:]][name] = value
            if firstValues[name] == nil {
                firstValues[name] = value
            }
        }

        return TimerSections(values: values, firstValues: firstValues)
    }

    private func hidIdleSeconds(in output: String) -> TimeInterval? {
        for line in output.components(separatedBy: .newlines) {
            guard let marker = line.range(of: "\"HIDIdleTime\" = ")?.upperBound else {
                continue
            }
            let digits = line[marker...].prefix { $0.isNumber }
            guard let nanoseconds = TimeInterval(String(digits)) else {
                continue
            }
            return nanoseconds / 1_000_000_000
        }
        return nil
    }

    private struct TimerSections {
        var values: [PowerSource: [String: Int]]
        var firstValues: [String: Int]
    }
}
