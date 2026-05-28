import AppKit
import SwiftUI

struct AboutMeView: View {
    @ObservedObject var store: WhyAwakeStore

    private var content: AboutMeContent {
        AboutMeContent.make(localizedBy: store.localizer)
    }

    var body: some View {
        VStack(spacing: 0) {
            hero

            Divider()

            VStack(alignment: .leading, spacing: 22) {
                LazyVGrid(columns: panelColumns, alignment: .center, spacing: 18) {
                    AuthorPanel(author: content.author)
                    GitHubPanel(github: content.github)
                }
                .frame(maxWidth: .infinity)

                Divider()

                HStack(alignment: .center) {
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Spacer(minLength: 16)

                    Text(content.footerNote)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .frame(width: 680)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial)
    }

    private var panelColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 18),
            GridItem(.flexible(), spacing: 18)
        ]
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 8) {
                Text(store.localized("Why Awake"))
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(1)

                Text(content.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Text(versionText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial)
                .clipShape(Capsule())
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        if let version, let build {
            return store.localized("Version %@ (%@)", version, build)
        }
        if let version {
            return store.localized("Version %@", version)
        }
        return store.localized("Version unavailable")
    }
}

private struct AuthorPanel: View {
    var author: AboutMeContent.Author

    var body: some View {
        InfoPanel(
            symbolName: author.symbolName,
            eyebrow: author.title,
            title: author.name,
            bodyText: author.detail
        )
    }
}

private struct GitHubPanel: View {
    var github: AboutMeContent.GitHub

    var body: some View {
        InfoPanel(
            symbolName: github.symbolName,
            eyebrow: github.title,
            title: github.repositoryName,
            bodyText: github.detail
        ) {
            Text(github.ownerName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            VStack(spacing: 8) {
                if let repositoryURL = github.repositoryURL {
                    AboutLinkRow(
                        title: github.repositoryURLText,
                        detail: "github.com/QuellaMC/Why-Awake",
                        systemImage: "folder",
                        destination: repositoryURL
                    )
                }

                if let profileURL = github.profileURL {
                    AboutLinkRow(
                        title: github.profileURLText,
                        detail: "github.com/QuellaMC",
                        systemImage: "person.crop.circle",
                        destination: profileURL
                    )
                }
            }
        }
    }
}

private struct AboutLinkRow: View {
    var title: String
    var detail: String
    var systemImage: String
    var destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct InfoPanel<Accessory: View>: View {
    var symbolName: String
    var eyebrow: String
    var title: String
    var bodyText: String
    @ViewBuilder var accessory: Accessory

    init(
        symbolName: String,
        eyebrow: String,
        title: String,
        bodyText: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.symbolName = symbolName
        self.eyebrow = eyebrow
        self.title = title
        self.bodyText = bodyText
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbolName)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            Text(bodyText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            accessory
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}

private extension InfoPanel where Accessory == EmptyView {
    init(
        symbolName: String,
        eyebrow: String,
        title: String,
        bodyText: String
    ) {
        self.init(
            symbolName: symbolName,
            eyebrow: eyebrow,
            title: title,
            bodyText: bodyText
        ) {
            EmptyView()
        }
    }
}

#if DEBUG
#Preview {
    AboutMeView(store: .preview)
}
#endif
