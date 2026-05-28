import Foundation
import Testing
@testable import Why_Awake

struct PolicyAndStoreTests {
    @Test func ignoreRulesMatchAppAndAssertionType() {
        let blocker = SleepBlocker(
            processName: "Amphetamine",
            pid: 53123,
            assertionType: "PreventUserIdleSystemSleep",
            reason: "Single use",
            activeDuration: 300,
            category: .systemSleep,
            ownerKind: .userApp,
            source: .process
        )

        #expect(IgnoreRule(appName: "Amphetamine", assertionType: nil).matches(blocker))
        #expect(IgnoreRule(appName: "Amphetamine", assertionType: "PreventUserIdleSystemSleep").matches(blocker))
        #expect(!IgnoreRule(appName: "Amphetamine", assertionType: "PreventUserIdleDisplaySleep").matches(blocker))
        #expect(!IgnoreRule(appName: "powerd", assertionType: nil).matches(blocker))
    }

    @Test func historyCountsNewIncidentsNotPollingSamples() {
        let store = InMemoryBlockerHistoryStore()
        let now = Date(timeIntervalSince1970: 1_000)
        let blocker = SleepBlocker(
            processName: "Codex",
            pid: 30894,
            assertionType: "NoIdleSleepAssertion",
            reason: "Electron",
            activeDuration: 120,
            category: .systemSleep,
            ownerKind: .userApp,
            source: .process
        )

        store.record([blocker], at: now)
        store.record([blocker.with(activeDuration: 180)], at: now.addingTimeInterval(60))
        store.record([], at: now.addingTimeInterval(120))
        store.record([blocker.with(activeDuration: 10)], at: now.addingTimeInterval(180))

        let entries = store.entries()
        #expect(entries.count == 1)
        #expect(entries[0].occurrences == 2)
        #expect(entries[0].firstSeen == now)
        #expect(entries[0].lastSeen == now.addingTimeInterval(180))
    }

    @Test func safetyPolicyProtectsSystemProcessesByDefault() {
        let systemBlocker = SleepBlocker(
            processName: "powerd",
            pid: 325,
            assertionType: "PreventUserIdleSystemSleep",
            reason: "Powerd - Prevent sleep while display is on",
            activeDuration: 500,
            category: .systemSleep,
            ownerKind: .system,
            source: .process
        )

        #expect(!AppActionPolicy.canQuit(systemBlocker))
        #expect(!AppActionPolicy.canForceQuit(systemBlocker))
        #expect(AppActionPolicy.explanation(for: systemBlocker).contains("owned by macOS"))
    }

    @Test func safetyPolicyDoesNotControlLowercaseDaemonLikeProcesses() {
        let daemonBlocker = SleepBlocker(
            processName: "sharingd",
            pid: 1200,
            assertionType: "PreventUserIdleSystemSleep",
            reason: "Background work",
            activeDuration: 100,
            category: .systemSleep,
            ownerKind: .system,
            source: .process
        )

        #expect(!AppActionPolicy.canQuit(daemonBlocker))
        #expect(!AppActionPolicy.canForceQuit(daemonBlocker))
    }

    @Test func runningApplicationNameMustMatchBeforeControl() {
        #expect(AppActionPolicy.matchesRunningApplicationName(
            "Music",
            localizedName: "Music",
            bundleURL: nil,
            executableURL: nil
        ))
        #expect(!AppActionPolicy.matchesRunningApplicationName(
            "Music",
            localizedName: "Calendar",
            bundleURL: nil,
            executableURL: nil
        ))
    }

    @Test func notificationPolicyOnlyAlertsForLongUserAppBlockers() {
        let oldUserBlocker = SleepBlocker(
            processName: "Amphetamine",
            pid: 53123,
            assertionType: "PreventUserIdleSystemSleep",
            reason: "Single use",
            activeDuration: 3_700,
            category: .systemSleep,
            ownerKind: .userApp,
            source: .process
        )
        let systemBlocker = oldUserBlocker.with(processName: "powerd", pid: 325, ownerKind: .system)
        let shortBlocker = oldUserBlocker.with(processName: "Codex", activeDuration: 120)

        let candidates = NotificationPolicy(threshold: 3_600).candidates(from: [oldUserBlocker, systemBlocker, shortBlocker], ignoredIDs: [])

        #expect(candidates == [oldUserBlocker])
    }

    @Test func keepAwakeStateReportsOwnedAssertionClearly() {
        let state = KeepAwakeState(mode: .display, assertionName: "Why Awake keep awake")

        #expect(state.isEnabled)
        #expect(state.keepsDisplayAwake)
        #expect(!state.keepsSystemAwake)
        #expect(state.displayName == "Display awake")
        #expect(state.explanation.contains("display on"))
    }

    @Test func keepAwakeStateCanRepresentDisplayAndSystemTogether() throws {
        let controller = InMemoryKeepAwakeController()

        try controller.setMode(.displayAndSystem)

        #expect(controller.state.isEnabled)
        #expect(controller.state.keepsDisplayAwake)
        #expect(controller.state.keepsSystemAwake)
        #expect(controller.state.displayName == "Display + system awake")
    }

    @MainActor
    @Test func refreshIntervalDefaultsToOneSecondAndCanBeChanged() {
        let store = WhyAwakeStore(assertionReader: StaticPowerAssertionClient(.empty))

        #expect(store.refreshInterval == 1)

        store.setRefreshInterval(5)
        #expect(store.refreshInterval == 5)
        #expect(store.refreshIntervalText == "5 seconds")

        store.setRefreshInterval(0.2)
        #expect(store.refreshInterval == 1)
    }

    @MainActor
    @Test func appPreferencesDefaultToSystemAndPersistUserOverrides() {
        let suiteName = "WhyAwakeTests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let languageKey = "language"
        let appearanceKey = "appearance"
        let store = WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(.empty),
            userDefaults: defaults,
            languagePreferenceDefaultsKey: languageKey,
            appearancePreferenceDefaultsKey: appearanceKey
        )

        #expect(store.languagePreference == .system)
        #expect(store.appearancePreference == .system)

        store.setLanguagePreference(.simplifiedChinese)
        store.setAppearancePreference(.dark)

        #expect(store.languagePreference == .simplifiedChinese)
        #expect(store.languagePreference.localeIdentifier == "zh-Hans")
        #expect(defaults.string(forKey: languageKey) == AppLanguagePreference.simplifiedChinese.rawValue)
        #expect(store.appearancePreference == .dark)
        #expect(defaults.string(forKey: appearanceKey) == AppAppearancePreference.dark.rawValue)
    }

    @MainActor
    @Test func firstRunTutorialShowsUntilCompleted() {
        let suiteName = "WhyAwakeTests.tutorial.firstRun.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let tutorialKey = "tutorialComplete"

        let firstRunStore = WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(.empty),
            userDefaults: defaults,
            tutorialCompletionDefaultsKey: tutorialKey
        )

        #expect(firstRunStore.isTutorialPresented)
        #expect(firstRunStore.currentTutorialStep == .sleepStatus)
        #expect(!defaults.bool(forKey: tutorialKey))

        firstRunStore.completeTutorial()

        #expect(!firstRunStore.isTutorialPresented)
        #expect(defaults.bool(forKey: tutorialKey))

        let completedStore = WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(.empty),
            userDefaults: defaults,
            tutorialCompletionDefaultsKey: tutorialKey
        )

        #expect(!completedStore.isTutorialPresented)
        #expect(completedStore.currentTutorialStep == .sleepStatus)
    }

    @MainActor
    @Test func tutorialNavigationClampsAndCompletesFromLastStep() {
        let store = WhyAwakeStore(assertionReader: StaticPowerAssertionClient(.empty))

        store.showTutorial()

        #expect(store.isTutorialPresented)
        #expect(store.currentTutorialStep == .sleepStatus)
        #expect(!store.canGoBackInTutorial)
        #expect(!store.isOnLastTutorialStep)

        store.previousTutorialStep()
        #expect(store.currentTutorialStep == .sleepStatus)

        for _ in 1..<TutorialStep.allCases.count {
            store.nextTutorialStep()
        }

        #expect(store.currentTutorialStep == TutorialStep.allCases.last!)
        #expect(store.canGoBackInTutorial)
        #expect(store.isOnLastTutorialStep)

        store.nextTutorialStep()

        #expect(!store.isTutorialPresented)
    }

    @MainActor
    @Test func skipTutorialPersistsCompletionAndShowTutorialReopensAtFirstStep() {
        let suiteName = "WhyAwakeTests.tutorial.skip.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let tutorialKey = "tutorialComplete"
        let store = WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(.empty),
            userDefaults: defaults,
            tutorialCompletionDefaultsKey: tutorialKey
        )

        store.nextTutorialStep()
        #expect(store.currentTutorialStep == .keepAwakeControls)

        store.skipTutorial()

        #expect(!store.isTutorialPresented)
        #expect(defaults.bool(forKey: tutorialKey))

        store.showTutorial()

        #expect(store.isTutorialPresented)
        #expect(store.currentTutorialStep == .sleepStatus)
        #expect(defaults.bool(forKey: tutorialKey))
    }

    @Test func appLocalizerLoadsLanguageOverrideResources() {
        let english = AppLocalizer(languagePreference: .english)
        let simplifiedChinese = AppLocalizer(languagePreference: .simplifiedChinese)

        #expect(english.string("Language") == "Language")
        #expect(simplifiedChinese.string("Language") == "语言")
        #expect(simplifiedChinese.string("%d seconds", 5) == "5 秒")
    }

    @MainActor
    @Test func unblockedStatusShowsOnlySleepTimerEvenAfterRecentInput() {
        let snapshot = WhyAwakeSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            activeAssertionTypes: ["UserIsActive"],
            blockers: []
        )
        let store = WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(snapshot),
            initialSnapshot: snapshot,
            initialPowerSettings: PowerSettings(
                displaySleepMinutes: 10,
                systemSleepMinutes: 20,
                hidIdleSeconds: 30
            )
        )

        #expect(store.displayStatusDetail == "Sleep in about 9m 30s.")
        #expect(store.systemStatusDetail == "Sleep in about 19m 30s.")
        #expect(!store.displayStatusDetail.contains("Recent input"))
        #expect(!store.systemStatusDetail.contains("No app blocker"))
    }

    @MainActor
    @Test func refreshCoalescesNewPollWhenPreviousPollIsStillRunning() async throws {
        let reader = FirstCallBlockingAssertionReader()
        let store = WhyAwakeStore(assertionReader: reader)

        store.refresh()
        #expect(try await eventually { await reader.callCount == 1 })

        store.refresh()
        #expect(await reader.callCount == 1)

        await reader.releaseFirstCall()
        #expect(try await eventually { await reader.callCount == 2 })
    }

    @MainActor
    @Test func stateChangingRefreshDoesNotCommitStaleInFlightResult() async throws {
        let blocker = SleepBlocker(
            processName: "Amphetamine",
            pid: 53123,
            assertionType: "PreventUserIdleSystemSleep",
            reason: "Single use",
            activeDuration: 300,
            category: .systemSleep,
            ownerKind: .userApp,
            source: .process
        )
        let snapshot = WhyAwakeSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            activeAssertionTypes: ["PreventUserIdleSystemSleep"],
            blockers: [blocker]
        )
        let reader = FirstCallBlockingAssertionReader(snapshot: snapshot)
        let store = WhyAwakeStore(assertionReader: reader)

        store.refresh()
        #expect(try await eventually { await reader.callCount == 1 })

        store.ignore(blocker)
        await reader.releaseFirstCall()

        #expect(try await eventually { await reader.callCount == 2 })
        #expect(try await eventually { await MainActor.run { store.snapshot.blockers.first?.isIgnored == true } })
        #expect(store.history.isEmpty)
    }

    @MainActor
    @Test func queuedRefreshDoesNotPublishStaleInFlightFailure() async throws {
        let reader = FirstCallFailingAssertionReader()
        let store = WhyAwakeStore(assertionReader: reader)

        store.refresh()
        #expect(try await eventually { await reader.callCount == 1 })

        store.refresh()
        await reader.releaseFirstCall()

        #expect(try await eventually { await reader.callCount == 2 })
        #expect(store.lastError == nil)
    }

    @MainActor
    @Test func successfulRefreshClearsTransientActionMessage() async throws {
        let store = WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(.empty),
            displaySleepService: StaticDisplaySleepService(result: .success("Asked macOS to sleep the display."))
        )

        store.putDisplayToSleepNow()
        #expect(try await eventually {
            await MainActor.run {
                store.lastMessage == "Asked macOS to sleep the display."
            }
        })

        store.refresh()
        #expect(try await eventually {
            await MainActor.run {
                store.lastMessage == nil && store.lastError == nil
            }
        })
    }

    @MainActor
    @Test func manualRefreshClearsTransientActionMessageWhilePaused() async throws {
        let store = WhyAwakeStore(
            assertionReader: StaticPowerAssertionClient(.empty),
            displaySleepService: StaticDisplaySleepService(result: .success("Asked macOS to sleep the display."))
        )

        store.toggleMonitoringPaused()
        store.putDisplayToSleepNow()
        #expect(try await eventually {
            await MainActor.run {
                store.lastMessage == "Asked macOS to sleep the display."
            }
        })
        #expect(store.isMonitoringPaused)

        store.refresh()
        #expect(try await eventually {
            await MainActor.run {
                store.lastMessage == nil && store.lastError == nil
            }
        })
    }

    @MainActor
    @Test func successMessageClearsStaleRefreshError() async throws {
        let store = WhyAwakeStore(assertionReader: AlwaysFailingAssertionReader())

        store.refresh()
        #expect(try await eventually {
            await MainActor.run {
                store.lastError != nil
            }
        })

        store.toggleMonitoringPaused()

        #expect(store.lastError == nil)
        #expect(store.lastMessage == "Monitoring paused.")
    }

    @Test func knowledgeBaseExplainsCommonAssertionsAndBlockers() {
        let blocker = SleepBlocker(
            processName: "Amphetamine",
            pid: 53123,
            assertionType: "PreventUserIdleSystemSleep",
            reason: "Amphetamine (Single-Use - System)",
            activeDuration: 300,
            category: .systemSleep,
            ownerKind: .userApp,
            source: .process
        )

        #expect(SleepBlockerKnowledge.assertionExplanation(for: blocker.assertionType).contains("idle system sleep"))
        #expect(SleepBlockerKnowledge.commonBlockerExplanation(for: blocker)?.contains("keep-awake") == true)
    }
}

private func eventually(
    timeout: TimeInterval = 1,
    pollIntervalNanoseconds: UInt64 = 5_000_000,
    _ condition: @escaping () async -> Bool
) async throws -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() {
            return true
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }
    return await condition()
}

private actor FirstCallBlockingAssertionReader: PowerAssertionReading {
    private var calls = 0
    private var firstCallContinuation: CheckedContinuation<Void, Never>?
    private let result: WhyAwakeSnapshot

    init(snapshot: WhyAwakeSnapshot = .empty) {
        result = snapshot
    }

    var callCount: Int {
        calls
    }

    func releaseFirstCall() {
        firstCallContinuation?.resume()
        firstCallContinuation = nil
    }

    func snapshot() async throws -> WhyAwakeSnapshot {
        calls += 1
        if calls == 1 {
            await withCheckedContinuation { continuation in
                firstCallContinuation = continuation
            }
        }
        return result
    }
}

private actor FirstCallFailingAssertionReader: PowerAssertionReading {
    private var calls = 0
    private var firstCallContinuation: CheckedContinuation<Void, Never>?

    var callCount: Int {
        calls
    }

    func releaseFirstCall() {
        firstCallContinuation?.resume()
        firstCallContinuation = nil
    }

    func snapshot() async throws -> WhyAwakeSnapshot {
        calls += 1
        if calls == 1 {
            await withCheckedContinuation { continuation in
                firstCallContinuation = continuation
            }
            throw TestRefreshError.staleFailure
        }
        return .empty
    }
}

private enum TestRefreshError: Error {
    case staleFailure
}

private struct AlwaysFailingAssertionReader: PowerAssertionReading {
    func snapshot() async throws -> WhyAwakeSnapshot {
        throw TestRefreshError.staleFailure
    }
}

private struct StaticDisplaySleepService: DisplaySleepServicing {
    let result: AppActionResult

    func sleepDisplayNow(localizer: AppLocalizer) async -> AppActionResult {
        result
    }
}
