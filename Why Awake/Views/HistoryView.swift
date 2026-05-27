import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.localized("Recurring Offenders"))
                    .font(.headline)
                Spacer()
                Button {
                    store.clearHistory()
                } label: {
                    Label(store.localized("Clear"), systemImage: "trash")
                }
                .disabled(store.history.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if store.history.isEmpty {
                ContentUnavailableView(store.localized("No history yet"), systemImage: "clock")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.history) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.processName)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.occurrences)x")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.assertionType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(store.localized("Last seen %@", entry.lastSeen.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
