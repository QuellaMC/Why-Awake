import AppKit
import Foundation

@MainActor
public final class WhyAwakeStore: ObservableObject {
    @Published public private(set) var snapshot: WhyAwakeSnapshot
    @Published public private(set) var history: [BlockerHistoryEntry]
    @Published public private(set) var ignoreRules: [IgnoreRule]
    @Published public private(set) var keepAwakeState: KeepAwakeState
    @Published public private(set) var powerSettings: PowerSettings
    @Published public private(set) var refreshInterval: TimeInterval
    @Published public private(set) var languagePreference: AppLanguagePreference
    @Published public private(set) var appearancePreference: AppAppearancePreference
    @Published public private(set) var isTutorialPresented: Bool
    @Published public private(set) var currentTutorialStep: TutorialStep
    @Published public var selectedBlockerID: SleepBlocker.ID?
    @Published public var isMonitoringPaused = false
    @Published public var lastMessage: String?
    @Published public var lastError: String?

    public nonisolated static let defaultRefreshInterval: TimeInterval = 1
    public nonisolated static let refreshIntervalOptions: [TimeInterval] = [1, 2, 5, 10, 30, 60]

    private let assertionReader: PowerAssertionReading
    private let powerSettingsReader: PowerSettingsReading
    private let ignoreStore: IgnoreRulesStoring
    private let historyStore: BlockerHistoryStoring
    private let appActions: AppActionServicing
    private let displaySleepService: DisplaySleepServicing
    private let keepAwakeController: KeepAwakeControlling
    private let notifier: SleepBlockerNotifying
    private let notificationPolicy: NotificationPolicy
    private let userDefaults: UserDefaults?
    private let refreshIntervalDefaultsKey: String?
    private let languagePreferenceDefaultsKey: String?
    private let appearancePreferenceDefaultsKey: String?
    private let tutorialCompletionDefaultsKey: String?
    private var notifiedBlockerIDs: Set<SleepBlocker.ID> = []
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var isRefreshInFlight = false
    private var hasPendingRefresh = false
    private var shouldDiscardInFlightResult = false

    public init(
        assertionReader: PowerAssertionReading,
        powerSettingsReader: PowerSettingsReading = StaticPowerSettingsClient(.unknown),
        ignoreStore: IgnoreRulesStoring = InMemoryIgnoreRulesStore(),
        historyStore: BlockerHistoryStoring = InMemoryBlockerHistoryStore(),
        appActions: AppActionServicing = MacAppActionService(),
        displaySleepService: DisplaySleepServicing = PMSetDisplaySleepService(),
        keepAwakeController: KeepAwakeControlling = InMemoryKeepAwakeController(),
        notifier: SleepBlockerNotifying = NoopNotificationService(),
        notificationPolicy: NotificationPolicy = NotificationPolicy(threshold: 3_600),
        initialSnapshot: WhyAwakeSnapshot = .empty,
        initialPowerSettings: PowerSettings = .unknown,
        initialRefreshInterval: TimeInterval = WhyAwakeStore.defaultRefreshInterval,
        initialLanguagePreference: AppLanguagePreference = .system,
        initialAppearancePreference: AppAppearancePreference = .system,
        userDefaults: UserDefaults? = nil,
        refreshIntervalDefaultsKey: String? = nil,
        languagePreferenceDefaultsKey: String? = nil,
        appearancePreferenceDefaultsKey: String? = nil,
        tutorialCompletionDefaultsKey: String? = nil
    ) {
        self.assertionReader = assertionReader
        self.powerSettingsReader = powerSettingsReader
        self.ignoreStore = ignoreStore
        self.historyStore = historyStore
        self.appActions = appActions
        self.displaySleepService = displaySleepService
        self.keepAwakeController = keepAwakeController
        self.notifier = notifier
        self.notificationPolicy = notificationPolicy
        self.userDefaults = userDefaults
        self.refreshIntervalDefaultsKey = refreshIntervalDefaultsKey
        self.languagePreferenceDefaultsKey = languagePreferenceDefaultsKey
        self.appearancePreferenceDefaultsKey = appearancePreferenceDefaultsKey
        self.tutorialCompletionDefaultsKey = tutorialCompletionDefaultsKey
        let loadedRules = ignoreStore.rules()
        snapshot = initialSnapshot.applyingIgnoreRules(loadedRules)
        history = historyStore.entries()
        ignoreRules = loadedRules
        keepAwakeState = keepAwakeController.state
        powerSettings = initialPowerSettings
        refreshInterval = Self.normalizedRefreshInterval(initialRefreshInterval)
        languagePreference = Self.loadedLanguagePreference(
            from: userDefaults,
            key: languagePreferenceDefaultsKey,
            fallback: initialLanguagePreference
        )
        appearancePreference = Self.loadedAppearancePreference(
            from: userDefaults,
            key: appearancePreferenceDefaultsKey,
            fallback: initialAppearancePreference
        )
        currentTutorialStep = .sleepStatus
        isTutorialPresented = Self.shouldPresentFirstRunTutorial(
            from: userDefaults,
            key: tutorialCompletionDefaultsKey
        )
    }

    public static func live() -> WhyAwakeStore {
        let notifier = UserNotificationService()
        notifier.requestAuthorization()
        let defaults = UserDefaults.standard
        let refreshIntervalDefaultsKey = "WhyAwake.refreshInterval"
        let storedRefreshInterval = defaults.double(forKey: refreshIntervalDefaultsKey)
        return WhyAwakeStore(
            assertionReader: PMSetPowerAssertionClient(),
            powerSettingsReader: PMSetPowerSettingsClient(),
            ignoreStore: UserDefaultsIgnoreRulesStore(),
            historyStore: UserDefaultsBlockerHistoryStore(),
            appActions: MacAppActionService(),
            displaySleepService: PMSetDisplaySleepService(),
            keepAwakeController: IOKitKeepAwakeController(),
            notifier: notifier,
            initialRefreshInterval: storedRefreshInterval > 0 ? storedRefreshInterval : defaultRefreshInterval,
            userDefaults: defaults,
            refreshIntervalDefaultsKey: refreshIntervalDefaultsKey,
            languagePreferenceDefaultsKey: "WhyAwake.languagePreference",
            appearancePreferenceDefaultsKey: "WhyAwake.appearancePreference",
            tutorialCompletionDefaultsKey: "WhyAwake.tutorialComplete"
        )
    }

    public var localizer: AppLocalizer {
        AppLocalizer(languagePreference: languagePreference)
    }

    public var appLocale: Locale {
        localizer.locale
    }

    public var blockers: [SleepBlocker] {
        snapshot.visibleBlockers
    }

    public var primaryBlockers: [SleepBlocker] {
        snapshot.primaryBlockers
    }

    public var secondaryBlockers: [SleepBlocker] {
        snapshot.secondaryBlockers
    }

    public func blockers(showingLowerSignalAssertions: Bool) -> [SleepBlocker] {
        showingLowerSignalAssertions ? blockers : primaryBlockers
    }

    public var selectedBlocker: SleepBlocker? {
        if let selectedBlockerID, let selected = blockers.first(where: { $0.id == selectedBlockerID }) {
            return selected
        }
        return primaryBlockers.first
    }

    public var displayStatusText: String {
        snapshot.displayState == .blocked ? localized("Display blocked") : localized("No display blocker")
    }

    public var systemStatusText: String {
        snapshot.systemState == .blocked ? localized("System blocked") : localized("No system blocker")
    }

    public var displayStatusDetail: String {
        if snapshot.displayState == .blocked {
            return snapshot.likelyDisplayExplanation(localizedBy: localizer)
        }
        return displaySleepTimerText
    }

    public var systemStatusDetail: String {
        if snapshot.systemState == .blocked {
            let count = primaryBlockers.filter { $0.category == .systemSleep }.count
            return count == 1
                ? localized("1 blocker keeping the Mac awake.")
                : localized("%d blockers keeping the Mac awake.", count)
        }
        return systemSleepTimerText
    }

    public var refreshIntervalText: String {
        Self.refreshIntervalLabel(for: refreshInterval, localizer: localizer)
    }

    public var hiddenAssertionsSummary: String {
        let count = secondaryBlockers.count
        if count == 1 {
            return localized("1 lower-signal assertion hidden")
        }
        return localized("%d lower-signal assertions hidden", count)
    }

    public var menuBarSystemImage: String {
        if snapshot.systemState == .blocked {
            return "moon.zzz.fill"
        }
        if snapshot.displayState == .blocked {
            return "display.trianglebadge.exclamationmark"
        }
        return "moon"
    }

    public var mostCommonUserBlocker: SleepBlocker? {
        primaryBlockers.first { $0.ownerKind == .userApp && !$0.isIgnored }
    }

    public var tutorialStepIndex: Int {
        TutorialStep.allCases.firstIndex(of: currentTutorialStep) ?? 0
    }

    public var tutorialStepCount: Int {
        TutorialStep.allCases.count
    }

    public var canGoBackInTutorial: Bool {
        tutorialStepIndex > 0
    }

    public var isOnLastTutorialStep: Bool {
        tutorialStepIndex == tutorialStepCount - 1
    }

    public func startMonitoring(interval: TimeInterval? = nil) {
        if let interval {
            refreshInterval = Self.normalizedRefreshInterval(interval)
            persistRefreshInterval()
        }
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromTimer()
            }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func toggleMonitoringPaused() {
        isMonitoringPaused.toggle()
        setTransientMessage(isMonitoringPaused ? localized("Monitoring paused.") : localized("Monitoring resumed."))
        if !isMonitoringPaused {
            refresh()
        }
    }

    public func setRefreshInterval(_ interval: TimeInterval) {
        let next = Self.normalizedRefreshInterval(interval)
        guard next != refreshInterval else { return }

        refreshInterval = next
        persistRefreshInterval()

        if timer != nil {
            timer?.invalidate()
            timer = nil
            startMonitoring()
        }

        setTransientMessage(localized("Refreshing every %@.", refreshIntervalText))
    }

    public func setLanguagePreference(_ preference: AppLanguagePreference) {
        guard preference != languagePreference else { return }
        languagePreference = preference
        persistLanguagePreference()
        setTransientMessage(localized("Language updated."))
    }

    public func setAppearancePreference(_ preference: AppAppearancePreference) {
        guard preference != appearancePreference else { return }
        appearancePreference = preference
        persistAppearancePreference()
        setTransientMessage(localized("Appearance updated."))
    }

    public func showTutorial() {
        currentTutorialStep = .sleepStatus
        isTutorialPresented = true
    }

    public func nextTutorialStep() {
        guard !isOnLastTutorialStep else {
            completeTutorial()
            return
        }
        currentTutorialStep = TutorialStep.allCases[tutorialStepIndex + 1]
    }

    public func previousTutorialStep() {
        guard canGoBackInTutorial else { return }
        currentTutorialStep = TutorialStep.allCases[tutorialStepIndex - 1]
    }

    public func skipTutorial() {
        finishTutorial()
    }

    public func completeTutorial() {
        finishTutorial()
    }

    private func finishTutorial() {
        isTutorialPresented = false
        persistTutorialCompletion()
    }

    public func refresh() {
        requestRefresh(discardInFlightResult: true, queueIfBusy: true, allowWhenPaused: true)
    }

    private func refreshFromTimer() {
        requestRefresh(discardInFlightResult: false, queueIfBusy: false, allowWhenPaused: false)
    }

    private func requestRefresh(discardInFlightResult: Bool, queueIfBusy: Bool, allowWhenPaused: Bool) {
        guard allowWhenPaused || !isMonitoringPaused else { return }
        guard !isRefreshInFlight else {
            guard queueIfBusy else { return }
            hasPendingRefresh = true
            shouldDiscardInFlightResult = shouldDiscardInFlightResult || discardInFlightResult
            return
        }
        isRefreshInFlight = true
        let assertionReader = assertionReader
        let powerSettingsReader = powerSettingsReader
        let loadedRules = ignoreStore.rules()
        ignoreRules = loadedRules

        refreshTask = Task { [weak self] in
            do {
                async let snapshotResult = assertionReader.snapshot()
                async let settingsResult = powerSettingsReader.settings()
                let next = try await snapshotResult.applyingIgnoreRules(loadedRules)
                let settings = try? await settingsResult
                guard !Task.isCancelled else {
                    self?.finishRefreshWithoutResult()
                    return
                }
                guard self?.shouldDiscardInFlightResult != true else {
                    self?.finishRefreshWithoutResult()
                    return
                }
                self?.finishRefresh(with: next, powerSettings: settings)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishRefreshWithoutResult()
                    return
                }
                guard self?.shouldDiscardInFlightResult != true else {
                    self?.finishRefreshWithoutResult()
                    return
                }
                self?.finishRefreshFailure(error)
            }
        }
    }

    private func finishRefresh(with next: WhyAwakeSnapshot, powerSettings nextPowerSettings: PowerSettings?) {
        snapshot = next
        if let nextPowerSettings {
            powerSettings = nextPowerSettings
        }
        if selectedBlockerID == nil || !next.visibleBlockers.contains(where: { $0.id == selectedBlockerID }) {
            selectedBlockerID = next.primaryBlockers.first?.id
        }
        recordHistory(from: next)
        notifyIfNeeded(from: next)
        lastError = nil
        lastMessage = nil
        finishRefreshCycle()
    }

    private func finishRefreshFailure(_ error: Error) {
        setStatusError(error.localizedDescription)
        finishRefreshCycle()
    }

    private func finishRefreshWithoutResult() {
        finishRefreshCycle()
    }

    private func finishRefreshCycle() {
        isRefreshInFlight = false
        refreshTask = nil

        let shouldRunPendingRefresh = hasPendingRefresh
        hasPendingRefresh = false
        shouldDiscardInFlightResult = false
        guard shouldRunPendingRefresh else { return }
        refresh()
    }

    public func open(_ blocker: SleepBlocker) {
        apply(appActions.open(blocker, localizer: localizer))
    }

    public func quit(_ blocker: SleepBlocker) {
        apply(appActions.quit(blocker, localizer: localizer))
        refresh()
    }

    public func forceQuit(_ blocker: SleepBlocker) {
        apply(appActions.forceQuit(blocker, localizer: localizer))
        refresh()
    }

    public func ignore(_ blocker: SleepBlocker) {
        ignoreStore.add(IgnoreRule(appName: blocker.processName, assertionType: blocker.assertionType))
        refresh()
    }

    public func removeIgnoreRule(_ rule: IgnoreRule) {
        ignoreStore.remove(id: rule.id)
        refresh()
    }

    public func putDisplayToSleepNow() {
        let displaySleepService = displaySleepService
        let localizer = localizer
        Task { [weak self] in
            let result = await displaySleepService.sleepDisplayNow(localizer: localizer)
            self?.apply(result)
        }
    }

    public func toggleDisplayKeepAwake() {
        setDisplayKeepAwake(!keepAwakeState.keepsDisplayAwake)
    }

    public func setDisplayKeepAwake(_ enabled: Bool) {
        updateKeepAwake(
            displayAwake: enabled,
            systemAwake: keepAwakeState.keepsSystemAwake
        )
    }

    public func toggleSystemKeepAwake() {
        setSystemKeepAwake(!keepAwakeState.keepsSystemAwake)
    }

    public func setSystemKeepAwake(_ enabled: Bool) {
        updateKeepAwake(
            displayAwake: keepAwakeState.keepsDisplayAwake,
            systemAwake: enabled
        )
    }

    public func releaseKeepAwake() {
        updateKeepAwake(displayAwake: false, systemAwake: false)
    }

    private func updateKeepAwake(displayAwake: Bool, systemAwake: Bool) {
        do {
            let nextMode = KeepAwakeMode(displayAwake: displayAwake, systemAwake: systemAwake)
            try keepAwakeController.setMode(nextMode)
            keepAwakeState = keepAwakeController.state
            setTransientMessage(keepAwakeState.explanation(localizedBy: localizer))
            refresh()
        } catch {
            setStatusError(error.localizedDescription)
        }
    }

    public func clearHistory() {
        historyStore.clear()
        history = []
    }

    private func recordHistory(from snapshot: WhyAwakeSnapshot) {
        let recordable = snapshot.blockers.filter { !$0.isIgnored }
        historyStore.record(recordable, at: snapshot.generatedAt)
        history = historyStore.entries()
    }

    private func notifyIfNeeded(from snapshot: WhyAwakeSnapshot) {
        let candidates = notificationPolicy.candidates(from: snapshot.blockers, ignoredIDs: notifiedBlockerIDs)
        for blocker in candidates {
            notifier.notifyLongRunningBlocker(blocker)
            notifiedBlockerIDs.insert(blocker.id)
        }
    }

    private func apply(_ result: AppActionResult) {
        switch result {
        case .success(let message), .blocked(let message):
            setTransientMessage(message)
        case .failed(let message):
            setStatusError(message)
        }
    }

    private func setTransientMessage(_ message: String) {
        lastMessage = message
        lastError = nil
    }

    private func setStatusError(_ message: String) {
        lastError = message
        lastMessage = nil
    }

    public func localized(_ key: String) -> String {
        AppLocalizer(languagePreference: languagePreference).string(key)
    }

    public func localized(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalizer(languagePreference: languagePreference).string(key, arguments: arguments)
    }

    private var displaySleepTimerText: String {
        timerText(
            minutes: powerSettings.displaySleepMinutes,
            remaining: powerSettings.displaySleepRemaining
        )
    }

    private var systemSleepTimerText: String {
        timerText(
            minutes: powerSettings.systemSleepMinutes,
            remaining: powerSettings.systemSleepRemaining
        )
    }

    private func timerText(minutes: Int?, remaining: TimeInterval?) -> String {
        guard let minutes else {
            return localized("Sleep timer unavailable.")
        }
        guard minutes > 0 else {
            return localized("Sleep set to Never.")
        }
        guard let remaining else {
            return localized("Sleep after %d min idle.", minutes)
        }
        if remaining <= 1 {
            return localized("Idle timer elapsed.")
        }
        let text = DurationFormatter.short.string(from: remaining) ?? "\(Int(remaining))s"
        return localized("Sleep in about %@.", text)
    }

    private func persistRefreshInterval() {
        guard let userDefaults, let refreshIntervalDefaultsKey else { return }
        userDefaults.set(refreshInterval, forKey: refreshIntervalDefaultsKey)
    }

    private func persistLanguagePreference() {
        guard let userDefaults, let languagePreferenceDefaultsKey else { return }
        userDefaults.set(languagePreference.rawValue, forKey: languagePreferenceDefaultsKey)
    }

    private func persistAppearancePreference() {
        guard let userDefaults, let appearancePreferenceDefaultsKey else { return }
        userDefaults.set(appearancePreference.rawValue, forKey: appearancePreferenceDefaultsKey)
    }

    private func persistTutorialCompletion() {
        guard let userDefaults, let tutorialCompletionDefaultsKey else { return }
        userDefaults.set(true, forKey: tutorialCompletionDefaultsKey)
    }

    private nonisolated static func shouldPresentFirstRunTutorial(from userDefaults: UserDefaults?, key: String?) -> Bool {
        guard let userDefaults, let key else { return false }
        return !userDefaults.bool(forKey: key)
    }

    private nonisolated static func normalizedRefreshInterval(_ interval: TimeInterval) -> TimeInterval {
        guard interval.isFinite else {
            return defaultRefreshInterval
        }
        return min(max(interval.rounded(), 1), 60)
    }

    public nonisolated static func refreshIntervalLabel(for interval: TimeInterval) -> String {
        refreshIntervalLabel(for: interval, localizer: AppLocalizer(languagePreference: .english))
    }

    public nonisolated static func refreshIntervalLabel(for interval: TimeInterval, localizer: AppLocalizer) -> String {
        let seconds = Int(normalizedRefreshInterval(interval))
        return seconds == 1 ? localizer.string("1 second") : localizer.string("%d seconds", seconds)
    }

    private nonisolated static func loadedLanguagePreference(
        from userDefaults: UserDefaults?,
        key: String?,
        fallback: AppLanguagePreference
    ) -> AppLanguagePreference {
        guard let userDefaults, let key, let rawValue = userDefaults.string(forKey: key) else {
            return fallback
        }
        return AppLanguagePreference.storedValue(rawValue)
    }

    private nonisolated static func loadedAppearancePreference(
        from userDefaults: UserDefaults?,
        key: String?,
        fallback: AppAppearancePreference
    ) -> AppAppearancePreference {
        guard let userDefaults, let key, let rawValue = userDefaults.string(forKey: key) else {
            return fallback
        }
        return AppAppearancePreference.storedValue(rawValue)
    }
}
