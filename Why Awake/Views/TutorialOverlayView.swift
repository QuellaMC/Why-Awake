import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject var store: WhyAwakeStore
    var highlightedRect: CGRect?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: cardAlignment(in: proxy.size)) {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                if let rect = highlightedRect {
                    TutorialHighlight(rect: rect)
                }

                TutorialCoachCard(store: store)
                    .frame(width: min(430, max(320, proxy.size.width - 48)))
                    .padding(24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeInOut(duration: 0.18), value: store.currentTutorialStep)
        }
        .accessibilityIdentifier("tutorialOverlay")
    }

    private func cardAlignment(in size: CGSize) -> Alignment {
        guard let highlightedRect else {
            return .center
        }

        let horizontal = highlightedRect.midX < size.width / 2 ? HorizontalAlignment.trailing : .leading
        let vertical: VerticalAlignment = highlightedRect.midY < size.height / 2 ? .bottom : .top

        if highlightedRect.height > size.height * 0.45 {
            return Alignment(horizontal: horizontal, vertical: .top)
        }

        if highlightedRect.width > size.width * 0.55 {
            return Alignment(horizontal: .center, vertical: vertical)
        }

        return Alignment(horizontal: horizontal, vertical: vertical)
    }
}

private struct TutorialHighlight: View {
    var rect: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.accentColor.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.95), lineWidth: 2)
            }
            .shadow(color: Color.accentColor.opacity(0.28), radius: 14)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

private struct TutorialCoachCard: View {
    @ObservedObject var store: WhyAwakeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(store.localized("Guided Tutorial"), systemImage: "questionmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(store.localized("Step %d of %d", store.tutorialStepIndex + 1, store.tutorialStepCount))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(store.currentTutorialStep.title(localizedBy: store.localizer))
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.currentTutorialStep.body(
                    localizedBy: store.localizer,
                    hasVisibleBlockers: !store.blockers.isEmpty
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    store.skipTutorial()
                } label: {
                    Text(store.localized("Skip"))
                }

                Spacer()

                Button {
                    store.previousTutorialStep()
                } label: {
                    Label(store.localized("Back"), systemImage: "chevron.left")
                }
                .disabled(!store.canGoBackInTutorial)

                Button {
                    store.nextTutorialStep()
                } label: {
                    Label(
                        store.isOnLastTutorialStep ? store.localized("Done") : store.localized("Next"),
                        systemImage: store.isOnLastTutorialStep ? "checkmark" : "chevron.right"
                    )
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(18)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.26), radius: 24, y: 12)
    }
}

#Preview {
    ContentView(store: .preview)
        .frame(width: 1_040, height: 680)
}
