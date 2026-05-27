import Foundation

public struct AboutMeContent: Equatable, Sendable {
    public struct Author: Equatable, Sendable {
        public let title: String
        public let name: String
        public let detail: String
        public let symbolName: String
    }

    public struct GitHub: Equatable, Sendable {
        public let title: String
        public let ownerName: String
        public let repositoryName: String
        public let detail: String
        public let profileURLText: String
        public let profileURL: URL?
        public let repositoryURLText: String
        public let repositoryURL: URL?
        public let symbolName: String
    }

    public let title: String
    public let subtitle: String
    public let author: Author
    public let github: GitHub
    public let footerNote: String

    public static func make(localizedBy localizer: AppLocalizer) -> AboutMeContent {
        AboutMeContent(
            title: localizer.string("About Me"),
            subtitle: localizer.string("I explain why your display or Mac is staying awake, then point you to safe actions."),
            author: Author(
                title: localizer.string("Author"),
                name: "Jiaying Wang",
                detail: localizer.string("Built as a local-first macOS utility for diagnosing sleep blockers without taking unsafe control away from other apps."),
                symbolName: "person.crop.circle"
            ),
            github: GitHub(
                title: localizer.string("GitHub"),
                ownerName: "QuellaMC",
                repositoryName: "QuellaMC/Why-Awake",
                detail: localizer.string("Source code, releases, issues, and implementation history live on GitHub."),
                profileURLText: localizer.string("GitHub Profile"),
                profileURL: URL(string: "https://github.com/QuellaMC"),
                repositoryURLText: localizer.string("Repository"),
                repositoryURL: URL(string: "https://github.com/QuellaMC/Why-Awake"),
                symbolName: "chevron.left.forwardslash.chevron.right"
            ),
            footerNote: localizer.string("Made with love")
        )
    }
}
