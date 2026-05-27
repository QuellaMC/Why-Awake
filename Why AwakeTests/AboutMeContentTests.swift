import Foundation
import Testing
@testable import Why_Awake

struct AboutMeContentTests {
    @Test func aboutMeContentExplainsLocalDiagnosisAndSafeControls() {
        let content = AboutMeContent.make(localizedBy: AppLocalizer(languagePreference: .english))

        #expect(content.title == "About Me")
        #expect(content.subtitle.contains("staying awake"))
        #expect(content.author.title == "Author")
        #expect(content.author.name == "Jiaying Wang")
        #expect(content.author.detail.contains("local-first"))
        #expect(content.github.title == "GitHub")
        #expect(content.github.ownerName == "QuellaMC")
        #expect(content.github.repositoryName == "QuellaMC/Why-Awake")
        #expect(content.github.detail.contains("Source code"))
        #expect(content.github.profileURL == URL(string: "https://github.com/QuellaMC"))
        #expect(content.github.repositoryURL == URL(string: "https://github.com/QuellaMC/Why-Awake"))
        #expect(content.footerNote == "Made with ♡")
    }
}
