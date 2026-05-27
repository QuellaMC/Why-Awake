import Foundation
import Testing
@testable import Why_Awake

struct PowerAssertionParserTests {
    private let sampleOutput = """
    2026-05-27 22:56:47 +0800
    Assertion status system-wide:
       BackgroundTask                 0
       ApplePushServiceTask           0
       UserIsActive                   1
       PreventUserIdleDisplaySleep    0
       PreventSystemSleep             0
       ExternalMedia                  1
       InternalPreventDisplaySleep    1
       PreventUserIdleSystemSleep     1
       NetworkClientActive            0
    Listed by owning process:
       pid 53123(Amphetamine): [0x0003c3b600018333] 01:05:36 PreventUserIdleSystemSleep named: "Amphetamine (Single-Use - System)"
       pid 30894(Codex): [0x0003d0b8000185b5] 00:10:06 NoIdleSleepAssertion named: "Electron"
       pid 325(powerd): [0x0003bb340001803b] 01:41:54 PreventUserIdleSystemSleep named: "Powerd - Prevent sleep while display is on"
       pid 325(powerd): [0x000044540008975d] 74:27:29 ExternalMedia named: "com.apple.powermanagement.externalmediamounted"
       pid 325(powerd): [0x0003d306001081eb] 00:00:16 InternalPreventDisplaySleep named: "com.apple.powermanagement.delayDisplayOff"
        Timeout will fire in 44 secs Action=TimeoutActionTurnOff
       pid 382(WindowServer): [0x0003d2ed0009869f] 00:00:14 UserIsActive named: "com.apple.iohideventsystem.queue.tickle serviceID:100001130 service:AppleUserHIDEventService product:USB Receiver eventType:17"
        Timeout will fire in 45 secs Action=TimeoutActionRelease
    Kernel Assertions: 0x124=USB,THNDR,MAGICWAKE
       id=553  level=255 0x4=USB creat=5/24/26, 15:53 description=com.apple.usb.externaldevice.01200000 owner=USB3.1 Hub
       id=566  level=255 0x100=MAGICWAKE creat=5/24/26, 15:51  mod=5/25/26, 21:03 description=en0 owner=IOSkywalkNetworkBSDClient
    """

    @Test func parsesProcessAssertionsAndCategories() throws {
        let snapshot = try PowerAssertionParser().parse(sampleOutput, at: Date(timeIntervalSince1970: 100))

        #expect(snapshot.blockers.count == 8)
        #expect(snapshot.displayState == .canSleep)
        #expect(snapshot.systemState == .blocked)
        #expect(snapshot.statusText == "System sleep blocked")
        #expect(snapshot.primaryBlockers.count == 2)
        #expect(snapshot.secondaryBlockers.count == 6)

        let amphetamine = try #require(snapshot.blockers.first { $0.processName == "Amphetamine" })
        #expect(amphetamine.pid == 53123)
        #expect(amphetamine.assertionType == "PreventUserIdleSystemSleep")
        #expect(amphetamine.reason == "Amphetamine (Single-Use - System)")
        #expect(amphetamine.activeDuration == 3_936)
        #expect(amphetamine.category == .systemSleep)
        #expect(amphetamine.ownerKind == .userApp)

        let external = try #require(snapshot.blockers.first { $0.assertionType == "ExternalMedia" })
        #expect(external.category == .externalMediaDevice)
        #expect(external.ownerKind == .system)

        let kernelUSB = try #require(snapshot.blockers.first { $0.processName == "USB3.1 Hub" })
        #expect(kernelUSB.pid == nil)
        #expect(kernelUSB.category == .externalMediaDevice)
    }

    @Test func ranksMostLikelyDisplayBlocker() throws {
        let output = """
        Assertion status system-wide:
           PreventUserIdleDisplaySleep    1
           UserIsActive                   1
        Listed by owning process:
           pid 70000(Zoom): [0x0003d2ed0009869f] 00:04:14 PreventUserIdleDisplaySleep named: "Video call"
           pid 382(WindowServer): [0x0003d2ee0009869f] 00:00:14 UserIsActive named: "Recent input"
        Kernel Assertions: 0x0=No Assertions
        """

        let snapshot = try PowerAssertionParser().parse(output, at: Date())

        #expect(snapshot.displayState == .blocked)
        #expect(snapshot.likelyDisplayBlocker?.processName == "Zoom")
        #expect(snapshot.likelyDisplayBlocker?.category == .displaySleep)
        #expect(snapshot.likelyDisplayExplanation == "Zoom is directly preventing display sleep.")
    }

    @Test func userActivityOnlyIsInformationalNotABlocker() throws {
        let output = """
        Assertion status system-wide:
           UserIsActive                   1
           PreventUserIdleDisplaySleep    0
           PreventUserIdleSystemSleep     0
        Listed by owning process:
           pid 382(WindowServer): [0x0003d2ee0009869f] 00:00:14 UserIsActive named: "Recent input"
        Kernel Assertions: 0x0=No Assertions
        """

        let snapshot = try PowerAssertionParser().parse(output, at: Date())

        #expect(snapshot.displayState == .canSleep)
        #expect(snapshot.systemState == .canSleep)
        #expect(snapshot.statusText == "Nothing blocks display sleep")
        #expect(snapshot.primaryBlockers.isEmpty)
        #expect(snapshot.secondaryBlockers.count == 1)
        #expect(snapshot.hasRecentUserActivity)
        #expect(snapshot.likelyDisplayBlocker == nil)
        #expect(snapshot.likelyDisplayExplanation == "No app or system assertion is blocking display sleep.")
    }

    @Test func emptyAssertionOutputMeansDisplayCanSleep() throws {
        let output = """
        Assertion status system-wide:
           UserIsActive                   0
           PreventUserIdleDisplaySleep    0
           PreventSystemSleep             0
           ExternalMedia                  0
           InternalPreventDisplaySleep    0
           PreventUserIdleSystemSleep     0
           NetworkClientActive            0
        Listed by owning process:
        Kernel Assertions: 0x0=No Assertions
        """

        let snapshot = try PowerAssertionParser().parse(output, at: Date())

        #expect(snapshot.blockers.isEmpty)
        #expect(snapshot.displayState == .canSleep)
        #expect(snapshot.systemState == .canSleep)
        #expect(snapshot.statusText == "Nothing blocks display sleep")
        #expect(snapshot.likelyDisplayBlocker == nil)
    }

    @Test func createdForContinuationAttributesSystemProxyToOwningApp() throws {
        let output = """
        Assertion status system-wide:
           PreventUserIdleSystemSleep     1
        Listed by owning process:
           pid 203(coreaudiod): [0x0003d0b8000185b5] 00:10:06 PreventUserIdleSystemSleep named: "Audio playback"
            Created for PID: 81234 (Music)
        Kernel Assertions: 0x0=No Assertions
        """

        let snapshot = try PowerAssertionParser().parse(output, at: Date())
        let blocker = try #require(snapshot.blockers.first)

        #expect(blocker.processName == "Music")
        #expect(blocker.pid == 81234)
        #expect(blocker.reason == "Audio playback")
        #expect(blocker.ownerKind == .userApp)
    }
}
