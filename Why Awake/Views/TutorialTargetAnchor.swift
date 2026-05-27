import SwiftUI

struct TutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialTargetRegion: [Anchor<CGRect>]] = [:]

    static func reduce(
        value: inout [TutorialTargetRegion: [Anchor<CGRect>]],
        nextValue: () -> [TutorialTargetRegion: [Anchor<CGRect>]]
    ) {
        for (region, anchors) in nextValue() {
            value[region, default: []].append(contentsOf: anchors)
        }
    }
}

extension View {
    func tutorialTarget(_ region: TutorialTargetRegion) -> some View {
        anchorPreference(key: TutorialTargetPreferenceKey.self, value: .bounds) { anchor in
            [region: [anchor]]
        }
    }
}
