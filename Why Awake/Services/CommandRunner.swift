import Foundation

public protocol CommandRunning: Sendable {
    func run(_ executable: URL, arguments: [String]) async throws -> String
}

public enum CommandRunnerError: Error, LocalizedError {
    case failed(executable: String, status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .failed(let executable, let status, let output):
            return "\(executable) exited with status \(status): \(output)"
        }
    }
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(_ executable: URL, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let collector = PipeCollector()
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.append(handle.availableData)
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.append(handle.availableData)
            }

            process.terminationHandler = { finishedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                collector.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
                collector.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

                let output = String(data: collector.data(), encoding: .utf8) ?? ""
                guard finishedProcess.terminationStatus == 0 else {
                    continuation.resume(
                        throwing: CommandRunnerError.failed(
                            executable: executable.path,
                            status: finishedProcess.terminationStatus,
                            output: output
                        )
                    )
                    return
                }

                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class PipeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func data() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
