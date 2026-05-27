import SwiftUI

struct StatusStripView: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                StatusCard(
                    title: store.displayStatusText,
                    detail: store.displayStatusDetail,
                    symbolName: store.snapshot.displayState == .blocked ? "display.trianglebadge.exclamationmark" : "display",
                    tint: store.snapshot.displayState == .blocked ? .red : .green
                )
                .tutorialTarget(.statusCards)

                StatusCard(
                    title: store.systemStatusText,
                    detail: store.systemStatusDetail,
                    symbolName: store.snapshot.systemState == .blocked ? "moon.zzz.fill" : "moon",
                    tint: store.snapshot.systemState == .blocked ? .orange : .green
                )
                .tutorialTarget(.statusCards)

                PowerControlsCard(store: store)
                    .tutorialTarget(.keepAwakeCard)
            }
        }
    }
}

private struct StatusCard: View {
    var title: String
    var detail: String
    var symbolName: String
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct PowerControlsCard: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: store.keepAwakeState.isEnabled ? "bolt.fill" : "bolt.slash")
                    .font(.title2)
                    .foregroundStyle(store.keepAwakeState.isEnabled ? Color.blue : Color.secondary)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.localized("Why Awake controls"))
                        .font(.headline)
                        .lineLimit(1)
                    Text(store.keepAwakeState.explanation(localizedBy: store.localizer))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 18) {
                KeepAwakeToggle(
                    title: store.localized("Display awake"),
                    symbolName: "display",
                    isOn: Binding(
                        get: { store.keepAwakeState.keepsDisplayAwake },
                        set: { store.setDisplayKeepAwake($0) }
                    ),
                    helpText: store.localized("Keep the display from turning off using an assertion owned by Why Awake.")
                )

                KeepAwakeToggle(
                    title: store.localized("System awake"),
                    symbolName: "moon.zzz",
                    isOn: Binding(
                        get: { store.keepAwakeState.keepsSystemAwake },
                        set: { store.setSystemKeepAwake($0) }
                    ),
                    helpText: store.localized("Prevent idle system sleep using an assertion owned by Why Awake.")
                )
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke((store.keepAwakeState.isEnabled ? Color.blue : Color.secondary).opacity(0.25), lineWidth: 1)
        }
    }
}

private struct KeepAwakeToggle: View {
    var title: String
    var symbolName: String
    @Binding var isOn: Bool
    var helpText: String

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                Text(title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: symbolName)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .help(helpText)
    }
}
