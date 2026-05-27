import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: WhyAwakeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            Button(store.localized("Show Blockers")) {
                if !MainWindowPresenter.activateExistingMainWindow() {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            Button(store.localized("Show Tutorial")) {
                store.showTutorial()
                if !MainWindowPresenter.activateExistingMainWindow() {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            Button(store.localized("About Me")) {
                openWindow(id: "about-me")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button(store.localized("Turn Display Off")) {
                store.putDisplayToSleepNow()
            }

            if let blocker = store.mostCommonUserBlocker {
                Button(store.localized("Quit %@", blocker.processName.menuTitle)) {
                    store.quit(blocker)
                }
            }

            Divider()

            Button(store.isMonitoringPaused ? store.localized("Resume Monitoring") : store.localized("Pause Monitoring")) {
                store.toggleMonitoringPaused()
            }

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

            Divider()

            Text(store.snapshot.statusText(localizedBy: store.localizer))
            Text(store.primaryBlockers.count == 1 ? store.localized("1 active blocker") : store.localized("%d active blockers", store.primaryBlockers.count))

            Divider()

            Button(store.localized("Quit Why Awake")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            store.startMonitoring()
        }
    }
}

private extension String {
    var menuTitle: String {
        if count <= 18 {
            return self
        }
        return String(prefix(17)) + "..."
    }
}
