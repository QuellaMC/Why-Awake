import Foundation

public struct PowerAssertionParser: Sendable {
    public enum ParseError: Error, LocalizedError {
        case missingAssertionStatus

        public var errorDescription: String? {
            switch self {
            case .missingAssertionStatus:
                "The pmset output did not contain an assertion status section."
            }
        }
    }

    public init() {}

    public func parse(_ output: String, at date: Date = Date()) throws -> WhyAwakeSnapshot {
        let lines = output.components(separatedBy: .newlines)
        var activeTypes: Set<String> = []
        var blockers: [SleepBlocker] = []
        var sawStatus = false
        var section: Section = .none
        var lastProcessBlockerIndex: Int?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line == "Assertion status system-wide:" {
                section = .status
                sawStatus = true
                continue
            }
            if line == "Listed by owning process:" {
                section = .processes
                continue
            }
            if line.hasPrefix("Kernel Assertions:") {
                section = .kernel
                continue
            }

            switch section {
            case .status:
                if let activeType = parseActiveStatusLine(line) {
                    activeTypes.insert(activeType)
                }
            case .processes:
                if let blocker = parseProcessLine(line) {
                    blockers.append(blocker)
                    lastProcessBlockerIndex = blockers.indices.last
                } else if let attribution = parseCreatedForLine(line),
                          let lastProcessBlockerIndex,
                          let attributed = attributedBlocker(blockers[lastProcessBlockerIndex], to: attribution) {
                    blockers[lastProcessBlockerIndex] = attributed
                }
            case .kernel:
                if let blocker = parseKernelLine(line) {
                    blockers.append(blocker)
                }
            case .none:
                continue
            }
        }

        guard sawStatus else {
            throw ParseError.missingAssertionStatus
        }

        return WhyAwakeSnapshot(generatedAt: date, activeAssertionTypes: activeTypes, blockers: blockers)
    }

    private func parseActiveStatusLine(_ line: String) -> String? {
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let last = parts.last, let value = Int(last), value > 0 else {
            return nil
        }
        return String(parts[0])
    }

    private func parseProcessLine(_ line: String) -> SleepBlocker? {
        guard line.hasPrefix("pid ") else { return nil }
        let afterPID = line.dropFirst(4)
        guard
            let openName = afterPID.firstIndex(of: "("),
            let closeName = afterPID[openName...].firstIndex(of: ")"),
            let pid = Int(afterPID[..<openName])
        else {
            return nil
        }

        let processName = String(afterPID[afterPID.index(after: openName)..<closeName])
        guard let bracketEnd = line.firstIndex(of: "]") else { return nil }
        let remainder = line[line.index(after: bracketEnd)...].trimmingCharacters(in: .whitespaces)
        let fields = remainder.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard fields.count >= 2 else { return nil }

        let activeDuration = Self.parseDuration(String(fields[0]))
        let assertionType = String(fields[1])
        let reason = fields.count == 3 ? Self.parseQuotedName(String(fields[2])) : assertionType
        let category = Self.category(for: assertionType)
        let ownerKind = Self.ownerKind(processName: processName, pid: pid)

        return SleepBlocker(
            processName: processName,
            pid: pid,
            assertionType: assertionType,
            reason: reason,
            activeDuration: activeDuration,
            category: category,
            ownerKind: ownerKind,
            source: .process
        )
    }

    private func parseKernelLine(_ line: String) -> SleepBlocker? {
        guard line.hasPrefix("id=") else { return nil }

        let typeToken = line
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .first { $0.hasPrefix("0x") && $0.contains("=") }
        guard let typeToken else { return nil }

        let assertionType = String(typeToken.split(separator: "=", maxSplits: 1).last ?? "Kernel")
        let description = Self.value(in: line, after: "description=", before: " owner=") ?? assertionType
        let owner = Self.value(in: line, after: " owner=", before: nil) ?? "Kernel"
        let category = Self.category(for: assertionType)

        return SleepBlocker(
            processName: owner,
            pid: nil,
            assertionType: assertionType,
            reason: description,
            activeDuration: 0,
            category: category,
            ownerKind: .system,
            source: .kernel
        )
    }

    private func parseCreatedForLine(_ line: String) -> CreatedForAttribution? {
        guard line.hasPrefix("Created for PID:") else { return nil }
        let tail = line.dropFirst("Created for PID:".count).trimmingCharacters(in: .whitespaces)
        let pidText = tail.prefix { $0.isNumber }
        guard let pid = Int(pidText) else { return nil }

        var processName: String?
        if let open = tail.firstIndex(of: "("),
           let close = tail[open...].firstIndex(of: ")"),
           open < close {
            processName = String(tail[tail.index(after: open)..<close])
        }

        return CreatedForAttribution(pid: pid, processName: processName)
    }

    private func attributedBlocker(_ blocker: SleepBlocker, to attribution: CreatedForAttribution) -> SleepBlocker? {
        guard let processName = attribution.processName, !processName.isEmpty else {
            return nil
        }

        return SleepBlocker(
            processName: processName,
            pid: attribution.pid,
            assertionType: blocker.assertionType,
            reason: blocker.reason,
            activeDuration: blocker.activeDuration,
            category: blocker.category,
            ownerKind: Self.ownerKind(processName: processName, pid: attribution.pid),
            source: blocker.source,
            isIgnored: blocker.isIgnored
        )
    }

    private static func parseQuotedName(_ input: String) -> String {
        guard let start = input.range(of: "named: \"")?.upperBound else {
            return input.trimmingCharacters(in: .whitespaces)
        }
        let tail = input[start...]
        guard let end = tail.firstIndex(of: "\"") else {
            return String(tail)
        }
        return String(tail[..<end])
    }

    private static func parseDuration(_ value: String) -> TimeInterval {
        let parts = value.split(separator: ":").compactMap { TimeInterval(String($0)) }
        guard parts.count == 3 else { return 0 }
        return parts[0] * 3_600 + parts[1] * 60 + parts[2]
    }

    private static func value(in line: String, after marker: String, before endMarker: String?) -> String? {
        guard let start = line.range(of: marker)?.upperBound else { return nil }
        let tail = line[start...]
        if let endMarker, let end = tail.range(of: endMarker)?.lowerBound {
            return String(tail[..<end]).trimmingCharacters(in: .whitespaces)
        }
        return String(tail).trimmingCharacters(in: .whitespaces)
    }

    private static func category(for assertionType: String) -> SleepBlockerCategory {
        let normalized = assertionType.lowercased()

        if normalized == "userisactive" {
            return .userActivity
        }
        if normalized.contains("display") {
            return .displaySleep
        }
        if normalized.contains("externalmedia")
            || normalized == "usb"
            || normalized == "thndr"
            || normalized.contains("thunderbolt") {
            return .externalMediaDevice
        }
        if normalized.contains("network")
            || normalized.contains("background")
            || normalized.contains("push")
            || normalized.contains("magicwake") {
            return .networkBackground
        }
        if normalized.contains("systemsleep")
            || normalized.contains("noidlesleep")
            || normalized.contains("preventsleep") {
            return .systemSleep
        }
        return .other
    }

    private static func ownerKind(processName: String, pid: Int?) -> SleepBlockerOwnerKind {
        let systemProcessNames: Set<String> = [
            "powerd",
            "windowserver",
            "kernel_task",
            "launchd",
            "loginwindow",
            "sharingd",
            "backupd",
            "bluetoothd",
            "coreaudiod",
            "distnoted",
            "hidd",
            "locationd",
            "mds",
            "mds_stores",
            "notifyd",
            "runningboardd",
            "securityd",
            "screensharingd"
        ]

        if systemProcessNames.contains(processName.lowercased()) {
            return .system
        }
        if let pid, pid > 0, pid < 500 {
            return .system
        }
        if processName == processName.lowercased(), !processName.contains(" ") {
            return .system
        }
        return .userApp
    }

    private struct CreatedForAttribution {
        var pid: Int
        var processName: String?
    }

    private enum Section {
        case none
        case status
        case processes
        case kernel
    }
}
