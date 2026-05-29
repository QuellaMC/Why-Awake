import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct Why_AwakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var store = WhyAwakeStore.live()

    var body: some Scene {
        WindowGroup("Why Awake", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 640)
                .environment(\.locale, store.appLocale)
                .preferredColorScheme(store.appearancePreference.colorScheme)
                .background(ApplicationActivationObserver { isActive in
                    store.setAppActive(isActive)
                })
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(store.localized("About Me")) {
                    openWindow(id: "about-me")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            CommandMenu(LocalizedStringKey(store.localized("Controls"))) {
                Button(store.localized("Refresh")) {
                    store.refresh()
                }
                .keyboardShortcut("r")

                Button(store.isMonitoringPaused ? store.localized("Resume Monitoring") : store.localized("Pause Monitoring")) {
                    store.toggleMonitoringPaused()
                }
                .keyboardShortcut("p")

                Button(store.localized("Turn Display Off")) {
                    store.putDisplayToSleepNow()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button(store.keepAwakeState.keepsDisplayAwake ? store.localized("Release Display Awake") : store.localized("Keep Display Awake")) {
                    store.setDisplayKeepAwake(!store.keepAwakeState.keepsDisplayAwake)
                }

                Button(store.keepAwakeState.keepsSystemAwake ? store.localized("Release System Awake") : store.localized("Keep System Awake")) {
                    store.setSystemKeepAwake(!store.keepAwakeState.keepsSystemAwake)
                }

                if store.keepAwakeState.isEnabled {
                    Button(store.localized("Release All Keep-Awake")) {
                        store.releaseKeepAwake()
                    }
                }
            }

            CommandGroup(replacing: .help) {
                Button(store.localized("About Me")) {
                    openWindow(id: "about-me")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Button(store.localized("Show Tutorial")) {
                    store.showTutorial()
                    if !MainWindowPresenter.activateExistingMainWindow() {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarContentView(store: store)
                .environment(\.locale, store.appLocale)
                .preferredColorScheme(store.appearancePreference.colorScheme)
        } label: {
            Label(store.localized("Why Awake"), systemImage: store.menuBarSystemImage)
        }

        Window("About Me", id: "about-me") {
            AboutMeView(store: store)
                .environment(\.locale, store.appLocale)
                .preferredColorScheme(store.appearancePreference.colorScheme)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(store: store)
                .environment(\.locale, store.appLocale)
                .preferredColorScheme(store.appearancePreference.colorScheme)
        }
    }
}

private struct ApplicationActivationObserver: NSViewRepresentable {
    var onActivationChange: (Bool) -> Void

    func makeNSView(context: Context) -> ApplicationActivationTrackingView {
        let view = ApplicationActivationTrackingView()
        view.onActivationChange = onActivationChange
        return view
    }

    func updateNSView(_ nsView: ApplicationActivationTrackingView, context: Context) {
        nsView.onActivationChange = onActivationChange
    }
}

private final class ApplicationActivationTrackingView: NSView {
    var onActivationChange: ((Bool) -> Void)?
    private var notificationTokens: [NSObjectProtocol] = []

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        observeApplicationActivation()
    }

    deinit {
        removeApplicationObservers()
    }

    private func observeApplicationActivation() {
        guard notificationTokens.isEmpty else { return }
        let center = NotificationCenter.default
        notificationTokens = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.onActivationChange?(true)
            },
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.onActivationChange?(false)
            }
        ]

        DispatchQueue.main.async { [weak self] in
            self?.onActivationChange?(NSApp.isActive)
        }
    }

    private func removeApplicationObservers() {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        notificationTokens = []
    }
}

private extension AppAppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
