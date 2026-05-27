import Foundation
import IOKit.pwr_mgt

public protocol KeepAwakeControlling: AnyObject {
    var state: KeepAwakeState { get }
    func setMode(_ mode: KeepAwakeMode) throws
}

public enum KeepAwakeError: Error, LocalizedError {
    case assertionFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .assertionFailed(let code):
            "Could not create the Why Awake power assertion. IOKit returned \(code)."
        }
    }
}

public final class InMemoryKeepAwakeController: KeepAwakeControlling {
    public private(set) var state: KeepAwakeState

    public init(state: KeepAwakeState = KeepAwakeState()) {
        self.state = state
    }

    public func setMode(_ mode: KeepAwakeMode) throws {
        state = KeepAwakeState(mode: mode)
    }
}

public final class IOKitKeepAwakeController: KeepAwakeControlling {
    public private(set) var state = KeepAwakeState()
    private var displayAssertionID: IOPMAssertionID = 0
    private var systemAssertionID: IOPMAssertionID = 0

    public init() {}

    deinit {
        releaseAssertions()
    }

    public func setMode(_ mode: KeepAwakeMode) throws {
        releaseAssertions()
        guard mode != .off else {
            state = KeepAwakeState(mode: .off)
            return
        }

        do {
            if mode.keepsDisplayAwake {
                displayAssertionID = try createAssertion(
                    type: kIOPMAssertionTypeNoDisplaySleep,
                    name: "Why Awake display keep awake"
                )
            }
            if mode.keepsSystemAwake {
                systemAssertionID = try createAssertion(
                    type: kIOPMAssertionTypeNoIdleSleep,
                    name: "Why Awake system keep awake"
                )
            }
        } catch {
            releaseAssertions()
            throw error
        }

        state = KeepAwakeState(mode: mode, assertionName: "Why Awake keep awake")
    }

    private func createAssertion(type: String, name: String) throws -> IOPMAssertionID {
        var newID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &newID
        )

        guard result == kIOReturnSuccess else {
            throw KeepAwakeError.assertionFailed(result)
        }

        return newID
    }

    private func releaseAssertions() {
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
        state = KeepAwakeState(mode: .off)
    }
}
