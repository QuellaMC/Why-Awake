import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        Form {
            Picker(store.localized("Language"), selection: Binding(
                get: { store.languagePreference },
                set: { store.setLanguagePreference($0) }
            )) {
                ForEach(AppLanguagePreference.allCases) { preference in
                    Text(preference.displayName(localizedBy: store.localizer))
                        .tag(preference)
                }
            }
            .help(store.localized("Use System to follow the macOS language preference."))

            Picker(store.localized("Appearance"), selection: Binding(
                get: { store.appearancePreference },
                set: { store.setAppearancePreference($0) }
            )) {
                ForEach(AppAppearancePreference.allCases) { preference in
                    Text(preference.displayName(localizedBy: store.localizer))
                        .tag(preference)
                }
            }
            .help(store.localized("Use System to follow the macOS light or dark appearance."))

            Toggle(isOn: Binding(
                get: { store.isMonitoringPaused },
                set: { newValue in
                    if newValue != store.isMonitoringPaused {
                        store.toggleMonitoringPaused()
                    }
                }
            )) {
                Text(store.localized("Pause monitoring"))
            }

            Picker(store.localized("Refresh interval"), selection: Binding(
                get: { store.refreshInterval },
                set: { store.setRefreshInterval($0) }
            )) {
                ForEach(WhyAwakeStore.refreshIntervalOptions, id: \.self) { interval in
                    Text(WhyAwakeStore.refreshIntervalLabel(for: interval, localizer: store.localizer))
                        .tag(interval)
                }
            }
            .help(store.localized("How often live monitoring refreshes power assertions and sleep timer data."))

            Toggle(isOn: Binding(
                get: { store.keepAwakeState.keepsDisplayAwake },
                set: { newValue in
                    if newValue != store.keepAwakeState.keepsDisplayAwake {
                        store.setDisplayKeepAwake(newValue)
                    }
                }
            )) {
                Text(store.localized("Keep display awake"))
            }

            Toggle(isOn: Binding(
                get: { store.keepAwakeState.keepsSystemAwake },
                set: { newValue in
                    if newValue != store.keepAwakeState.keepsSystemAwake {
                        store.setSystemKeepAwake(newValue)
                    }
                }
            )) {
                Text(store.localized("Keep system awake"))
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
