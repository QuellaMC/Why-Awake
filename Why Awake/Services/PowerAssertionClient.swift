import Foundation

public protocol PowerAssertionReading: Sendable {
    func snapshot() async throws -> WhyAwakeSnapshot
}

public struct PMSetPowerAssertionClient: PowerAssertionReading {
    private let runner: CommandRunning
    private let parser: PowerAssertionParser

    public init(runner: CommandRunning = ProcessCommandRunner(), parser: PowerAssertionParser = PowerAssertionParser()) {
        self.runner = runner
        self.parser = parser
    }

    public func snapshot() async throws -> WhyAwakeSnapshot {
        let output = try await runner.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["-g", "assertions"])
        return try parser.parse(output)
    }
}

public struct StaticPowerAssertionClient: PowerAssertionReading {
    public var currentSnapshot: WhyAwakeSnapshot

    public init(_ snapshot: WhyAwakeSnapshot) {
        currentSnapshot = snapshot
    }

    public func snapshot() async throws -> WhyAwakeSnapshot {
        currentSnapshot
    }
}
