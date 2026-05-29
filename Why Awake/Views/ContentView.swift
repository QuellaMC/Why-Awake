import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        VStack(spacing: 0) {
            StatusStripView(store: store)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Divider()

            HSplitView {
                BlockersListView(store: store)
                    .frame(minWidth: 420, idealWidth: 540)

                InspectorTabsView(store: store)
                    .frame(minWidth: 360, idealWidth: 420)
            }
            .frame(maxHeight: .infinity)

            Divider()

            FooterMessageView(store: store)
        }
        .overlayPreferenceValue(TutorialTargetPreferenceKey.self) { targets in
            GeometryReader { proxy in
                if store.isTutorialPresented {
                    TutorialOverlayView(
                        store: store,
                        highlightedRect: tutorialHighlightRect(from: targets, in: proxy)
                    )
                    .zIndex(1)
                    .transition(.opacity)
                }
            }
        }
        .navigationTitle(store.localized("Why Awake"))
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.refresh()
                } label: {
                    Label(store.localized("Refresh"), systemImage: "arrow.clockwise")
                }
                .tutorialTarget(.toolbar)
                .keyboardShortcut("r")
                .help(store.localized("Refresh power assertions and sleep timer data now."))

                Button {
                    store.toggleMonitoringPaused()
                } label: {
                    Label(store.isMonitoringPaused ? store.localized("Resume") : store.localized("Pause"), systemImage: store.isMonitoringPaused ? "play.fill" : "pause.fill")
                }
                .tutorialTarget(.toolbar)
                .help(store.isMonitoringPaused ? store.localized("Resume live monitoring.") : store.localized("Pause automatic refresh without quitting the app."))

                Button {
                    store.putDisplayToSleepNow()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "display")
                        Text(store.localized("Turn Display Off"))
                    }
                }
                .tutorialTarget(.toolbar)
                .help(store.localized("Ask macOS to turn the display off now. This does not revoke another app's assertion."))
            }
        }
        .onAppear {
            store.startMonitoring()
        }
    }

    private func tutorialHighlightRect(
        from targets: [TutorialTargetRegion: [Anchor<CGRect>]],
        in proxy: GeometryProxy
    ) -> CGRect? {
        guard let anchors = targets[store.currentTutorialStep.targetRegion], !anchors.isEmpty else {
            return nil
        }

        let rects = anchors.map { proxy[$0] }
        guard let first = rects.first else { return nil }
        return rects
            .dropFirst()
            .reduce(first) { $0.union($1) }
            .insetBy(dx: -6, dy: -6)
    }
}

private struct InspectorTabsView: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        BlockerDetailView(store: store, blocker: store.selectedBlocker)
    }
}

private struct FooterMessageView: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        HStack(spacing: 8) {
            if let lastError = store.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let lastMessage = store.lastMessage {
                Label(lastMessage, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label(store.localized("Updated %@", store.snapshot.generatedAt.formatted(date: .omitted, time: .standard)), systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(store.monitoringFooterStatusText, systemImage: store.monitoringFooterStatusSystemImage)
                .foregroundStyle(monitoringFooterStatusColor)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var monitoringFooterStatusColor: Color {
        store.isMonitoringPaused || !store.isMonitoringWindowFocused ? .orange : .green
    }
}

#if DEBUG
#Preview {
    ContentView(store: .preview)
        .frame(width: 1_040, height: 680)
}
#endif
