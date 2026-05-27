import SwiftUI

struct BlockersListView: View {
    @ObservedObject var store: WhyAwakeStore
    @State private var collapsedCategories: Set<SleepBlockerCategory> = []
    @State private var showsLowerSignalAssertions = false

    private var listedBlockers: [SleepBlocker] {
        store.blockers(showingLowerSignalAssertions: showsLowerSignalAssertions)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.localized("Blockers"))
                    .font(.headline)
                Spacer()
                if !store.secondaryBlockers.isEmpty {
                    Button {
                        showsLowerSignalAssertions.toggle()
                    } label: {
                        Label(
                            showsLowerSignalAssertions ? store.localized("Hide less relevant") : store.hiddenAssertionsSummary,
                            systemImage: showsLowerSignalAssertions ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                        )
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help(showsLowerSignalAssertions ? store.localized("Hide user activity, external media, network, and other lower-signal assertions.") : store.localized("Show lower-signal assertions as context."))
                }
                Text("\(listedBlockers.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if listedBlockers.isEmpty {
                ContentUnavailableView(
                    store.localized("No app is blocking sleep"),
                    systemImage: "moon",
                    description: Text(emptyDescription)
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $store.selectedBlockerID) {
                    ForEach(SleepBlockerCategory.allCases) { category in
                        let categoryBlockers = listedBlockers.filter { $0.category == category }
                        if !categoryBlockers.isEmpty {
                            CategoryHeaderRow(
                                category: category,
                                localizer: store.localizer,
                                count: categoryBlockers.count,
                                isCollapsed: collapsedCategories.contains(category)
                            ) {
                                toggle(category)
                            }
                            .listRowSeparator(.hidden)

                            if !collapsedCategories.contains(category) {
                                ForEach(categoryBlockers) { blocker in
                                    BlockerRow(blocker: blocker, localizer: store.localizer)
                                        .tag(blocker.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .tutorialTarget(.blockersList)
    }

    private var emptyDescription: String {
        if !store.secondaryBlockers.isEmpty {
            return store.localized("%@. Use the filter button to show them as context.", store.hiddenAssertionsSummary)
        }
        return store.localized("macOS reports no app or system assertion that is blocking display or system sleep.")
    }

    private func toggle(_ category: SleepBlockerCategory) {
        if collapsedCategories.contains(category) {
            collapsedCategories.remove(category)
        } else {
            collapsedCategories.insert(category)
        }
    }
}

private struct CategoryHeaderRow: View {
    var category: SleepBlockerCategory
    var localizer: AppLocalizer
    var count: Int
    var isCollapsed: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Label(category.title(localizedBy: localizer), systemImage: category.symbolName)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .help(isCollapsed ? localizer.string("Expand %@", category.title(localizedBy: localizer)) : localizer.string("Collapse %@", category.title(localizedBy: localizer)))
    }
}

private struct BlockerRow: View {
    var blocker: SleepBlocker
    var localizer: AppLocalizer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: blocker.category.symbolName)
                .font(.body)
                .foregroundStyle(blocker.isIgnored ? .secondary : categoryTint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(blocker.processName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if blocker.ownerKind == .system {
                        Text(localizer.string("System"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if blocker.isIgnored {
                        Text(localizer.string("Ignored"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer(minLength: 0)
                    Text(blocker.durationText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text("\(blocker.assertionType) - \(blocker.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .opacity(blocker.isIgnored ? 0.62 : 1)
    }

    private var categoryTint: Color {
        switch blocker.category {
        case .displaySleep:
            .red
        case .systemSleep:
            .orange
        case .userActivity:
            .blue
        case .externalMediaDevice:
            .purple
        case .networkBackground:
            .teal
        case .other:
            .secondary
        }
    }
}
