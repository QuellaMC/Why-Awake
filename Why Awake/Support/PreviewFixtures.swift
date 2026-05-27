import Foundation

extension WhyAwakeStore {
    static var preview: WhyAwakeStore {
        let snapshot = WhyAwakeSnapshot(
            generatedAt: Date(),
            activeAssertionTypes: ["UserIsActive", "PreventUserIdleSystemSleep"],
            blockers: [
                SleepBlocker(
                    processName: "Amphetamine",
                    pid: 53123,
                    assertionType: "PreventUserIdleSystemSleep",
                    reason: "Amphetamine (Single-Use - System)",
                    activeDuration: 3_936,
                    category: .systemSleep,
                    ownerKind: .userApp,
                    source: .process
                ),
                SleepBlocker(
                    processName: "WindowServer",
                    pid: 382,
                    assertionType: "UserIsActive",
                    reason: "USB Receiver activity",
                    activeDuration: 14,
                    category: .userActivity,
                    ownerKind: .system,
                    source: .process
                ),
                SleepBlocker(
                    processName: "USB3.1 Hub",
                    pid: nil,
                    assertionType: "USB",
                    reason: "com.apple.usb.externaldevice.01200000",
                    activeDuration: 0,
                    category: .externalMediaDevice,
                    ownerKind: .system,
                    source: .kernel
                )
            ]
        )
        let history = InMemoryBlockerHistoryStore()
        history.record(snapshot.blockers, at: snapshot.generatedAt)
        return WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(snapshot),
            powerSettingsReader: StaticPowerSettingsClient(PowerSettings(displaySleepMinutes: 10, systemSleepMinutes: 30, hidIdleSeconds: 125)),
            historyStore: history,
            initialSnapshot: snapshot,
            initialPowerSettings: PowerSettings(displaySleepMinutes: 10, systemSleepMinutes: 30, hidIdleSeconds: 125)
        )
    }
}
