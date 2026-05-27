import Foundation
import Testing
@testable import Why_Awake

struct PowerSettingsParserTests {
    @Test func clientReadsPowerSourceBeforeChoosingTimer() async throws {
        let runner = RecordingCommandRunner(
            pmsetOutput: """
            Battery Power:
             displaysleep         2
             sleep                5
            AC Power:
             displaysleep         15
             sleep                45
            """,
            powerSourceOutput: "Now drawing from 'AC Power'",
            ioregOutput: """
                "HIDIdleTime" = 60000000000
            """
        )
        let client = PMSetPowerSettingsClient(runner: runner)

        let settings = try await client.settings()
        let calls = await runner.calls

        #expect(calls.contains(RecordedCommand(executable: "/usr/bin/pmset", arguments: ["-g", "ps"])))
        #expect(settings.activePowerSource == .powerAdapter)
        #expect(settings.displaySleepMinutes == 15)
        #expect(settings.displaySleepRemaining.map { Int($0) } == 840)
    }

    @Test func parsesSleepTimersAndHIDIdleTime() {
        let pmsetOutput = """
        AC Power:
         displaysleep         10
         sleep                30
         disksleep            10
        """
        let ioregOutput = """
            "HIDIdleTime" = 38754207500
        """

        let settings = PowerSettingsParser().parse(
            pmsetOutput: pmsetOutput,
            ioregOutput: ioregOutput,
            powerSourceOutput: "Now drawing from 'AC Power'"
        )

        #expect(settings.displaySleepMinutes == 10)
        #expect(settings.systemSleepMinutes == 30)
        #expect(settings.activePowerSource == .powerAdapter)
        #expect(settings.hidIdleSeconds.map { Int($0 * 1_000) } == 38_754)
        #expect(settings.displaySleepRemaining.map { Int($0) } == 561)
        #expect(settings.systemSleepRemaining.map { Int($0) } == 1_761)
    }

    @Test func zeroSleepTimerMeansNever() {
        let pmsetOutput = """
        AC Power:
         displaysleep         0
         sleep                0
        """

        let settings = PowerSettingsParser().parse(pmsetOutput: pmsetOutput, ioregOutput: "")

        #expect(settings.displaySleepMinutes == 0)
        #expect(settings.systemSleepMinutes == 0)
        #expect(settings.displaySleepRemaining == nil)
        #expect(settings.systemSleepRemaining == nil)
    }

    @Test func usesPowerAdapterTimersWhenMacIsPluggedIn() {
        let pmsetOutput = """
        Battery Power:
         displaysleep         2
         sleep                5
        AC Power:
         displaysleep         15
         sleep                45
        """
        let ioregOutput = """
            "HIDIdleTime" = 60000000000
        """

        let settings = PowerSettingsParser().parse(
            pmsetOutput: pmsetOutput,
            ioregOutput: ioregOutput,
            powerSourceOutput: "Now drawing from 'AC Power'"
        )

        #expect(settings.activePowerSource == .powerAdapter)
        #expect(settings.displaySleepMinutes == 15)
        #expect(settings.systemSleepMinutes == 45)
        #expect(settings.displaySleepRemaining.map { Int($0) } == 840)
        #expect(settings.systemSleepRemaining.map { Int($0) } == 2_640)
    }

    @Test func usesBatteryTimersWhenMacIsOnBattery() {
        let pmsetOutput = """
        Battery Power:
         displaysleep         2
         sleep                5
        AC Power:
         displaysleep         15
         sleep                45
        """

        let settings = PowerSettingsParser().parse(
            pmsetOutput: pmsetOutput,
            ioregOutput: "",
            powerSourceOutput: "Now drawing from 'Battery Power'"
        )

        #expect(settings.activePowerSource == .battery)
        #expect(settings.displaySleepMinutes == 2)
        #expect(settings.systemSleepMinutes == 5)
    }
}

private actor RecordingCommandRunner: CommandRunning {
    private let pmsetOutput: String
    private let powerSourceOutput: String
    private let ioregOutput: String
    private var recorded: [RecordedCommand] = []

    init(pmsetOutput: String, powerSourceOutput: String, ioregOutput: String) {
        self.pmsetOutput = pmsetOutput
        self.powerSourceOutput = powerSourceOutput
        self.ioregOutput = ioregOutput
    }

    var calls: [RecordedCommand] {
        recorded
    }

    func run(_ executable: URL, arguments: [String]) async throws -> String {
        recorded.append(RecordedCommand(executable: executable.path, arguments: arguments))
        if executable.path == "/usr/bin/pmset", arguments == ["-g", "custom"] {
            return pmsetOutput
        }
        if executable.path == "/usr/bin/pmset", arguments == ["-g", "ps"] {
            return powerSourceOutput
        }
        if executable.path == "/usr/sbin/ioreg", arguments == ["-c", "IOHIDSystem", "-r"] {
            return ioregOutput
        }
        throw RecordingCommandRunnerError.unexpectedCommand(executable.path, arguments)
    }
}

private struct RecordedCommand: Equatable, Sendable {
    let executable: String
    let arguments: [String]
}

private enum RecordingCommandRunnerError: Error {
    case unexpectedCommand(String, [String])
}
