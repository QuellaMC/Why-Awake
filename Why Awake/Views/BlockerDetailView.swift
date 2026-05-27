import SwiftUI

struct BlockerDetailView: View {
    @ObservedObject var store: WhyAwakeStore
    var blocker: SleepBlocker?
    @State private var showForceQuitWarning = false
    @State private var selectedTab: DetailTab = .summary

    var body: some View {
        Group {
            if let blocker {
                TabView(selection: $selectedTab) {
                    ScrollView {
                        summary(for: blocker)
                    }
                    .tabItem {
                        Label(store.localized("Summary"), systemImage: "list.bullet.rectangle")
                    }
                    .tag(DetailTab.summary)

                    ScrollView {
                        meaning(for: blocker)
                    }
                    .tabItem {
                        Label(store.localized("Why"), systemImage: "questionmark.circle")
                    }
                    .tag(DetailTab.meaning)

                    ScrollView {
                        technicalDetails(for: blocker)
                    }
                    .tabItem {
                        Label(store.localized("Technical"), systemImage: "info.circle")
                    }
                    .tag(DetailTab.technical)
                }
                .padding(.top, 8)
                .alert(store.localized("Force quit %@?", blocker.processName), isPresented: $showForceQuitWarning) {
                    Button(store.localized("Force Quit"), role: .destructive) {
                        store.forceQuit(blocker)
                    }
                    Button(store.localized("Cancel"), role: .cancel) {}
                } message: {
                    Text(store.localized("Force quit can discard unsaved work. Use it only when normal quit does not release the blocker."))
                }
            } else {
                ContentUnavailableView(store.localized("Select a blocker"), systemImage: "sidebar.right")
            }
        }
        .tutorialTarget(.detailInspector)
    }

    private func summary(for blocker: SleepBlocker) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            header(for: blocker)
            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                detailRow(store.localized("Reason"), blocker.reason)
                detailRow(store.localized("Active"), blocker.durationText)
                detailRow(store.localized("Assertion"), blocker.assertionType)
                detailRow(store.localized("Owner"), blocker.ownerKind == .system ? store.localized("macOS / system") : store.localized("User app"))
            }
            .font(.callout)

            Divider()
            appActions(for: blocker)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func meaning(for blocker: SleepBlocker) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            assertionExplanation(for: blocker)
            Divider()
            explanation(for: blocker)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func technicalDetails(for blocker: SleepBlocker) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            fields(for: blocker)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func header(for blocker: SleepBlocker) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: blocker.category.symbolName)
                .font(.title)
                .foregroundStyle(blocker.ownerKind == .system ? Color.secondary : Color.accentColor)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(blocker.processName)
                    .font(.title3.weight(.semibold))
                Text(blocker.category.title(localizedBy: store.localizer))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func fields(for blocker: SleepBlocker) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            detailRow(store.localized("PID"), blocker.pidText)
            detailRow(store.localized("Assertion"), blocker.assertionType)
            detailRow(store.localized("Reason"), blocker.reason)
            detailRow(store.localized("Active"), blocker.durationText)
            detailRow(store.localized("Owner"), blocker.ownerKind == .system ? store.localized("macOS / system") : store.localized("User app"))
            detailRow(store.localized("Source"), blocker.source == .kernel ? store.localized("Kernel assertion") : store.localized("Process assertion"))
        }
        .font(.callout)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explanation(for blocker: SleepBlocker) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.localized("Control"))
                .font(.headline)
            Text(AppActionPolicy.explanation(for: blocker, localizedBy: store.localizer))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func assertionExplanation(for blocker: SleepBlocker) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.localized("What this means"))
                .font(.headline)

            ExplanationLine(title: store.localized("Assertion"), text: SleepBlockerKnowledge.assertionExplanation(for: blocker.assertionType, localizedBy: store.localizer))
            ExplanationLine(title: store.localized("Category"), text: SleepBlockerKnowledge.categoryExplanation(for: blocker.category, localizedBy: store.localizer))

            if let common = SleepBlockerKnowledge.commonBlockerExplanation(for: blocker, localizedBy: store.localizer) {
                ExplanationLine(title: store.localized("Common case"), text: common)
            }
        }
    }

    private func appActions(for blocker: SleepBlocker) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.localized("App actions"))
                .font(.headline)

            HStack(spacing: 8) {
                Button {
                    store.open(blocker)
                } label: {
                    Label(store.localized("Open"), systemImage: "arrow.up.right.square")
                }
                .disabled(!AppActionPolicy.canOpen(blocker))

                Button {
                    store.quit(blocker)
                } label: {
                    Label(store.localized("Quit"), systemImage: "xmark.circle")
                }
                .disabled(!AppActionPolicy.canQuit(blocker))

                Button(role: .destructive) {
                    showForceQuitWarning = true
                } label: {
                    Label(store.localized("Force Quit"), systemImage: "exclamationmark.octagon")
                }
                .disabled(!AppActionPolicy.canForceQuit(blocker))

                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Text(AppActionPolicy.explanation(for: blocker, localizedBy: store.localizer))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tutorialTarget(.detailActions)
    }
}

private enum DetailTab: Hashable {
    case summary
    case meaning
    case technical
}

private struct ExplanationLine: View {
    var title: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
