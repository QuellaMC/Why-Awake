import Foundation

public enum AppLanguagePreference: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }

    public var localeIdentifier: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }

    public var localizationCode: String? {
        localeIdentifier
    }

    public static func storedValue(_ rawValue: String?) -> AppLanguagePreference {
        guard let rawValue, let preference = AppLanguagePreference(rawValue: rawValue) else {
            return .system
        }
        return preference
    }
}

public enum AppAppearancePreference: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public static func storedValue(_ rawValue: String?) -> AppAppearancePreference {
        guard let rawValue, let preference = AppAppearancePreference(rawValue: rawValue) else {
            return .system
        }
        return preference
    }
}
