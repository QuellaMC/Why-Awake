import SwiftUI

struct IgnoreRulesView: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.localized("Ignore Rules"))
                    .font(.headline)
                Spacer()
                Text("\(store.ignoreRules.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if store.ignoreRules.isEmpty {
                ContentUnavailableView(store.localized("No ignore rules"), systemImage: "eye.slash")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.ignoreRules) { rule in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.appName ?? store.localized("Any app"))
                                .font(.body.weight(.medium))
                            Text(rule.assertionType ?? store.localized("Any assertion"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            store.removeIgnoreRule(rule)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
