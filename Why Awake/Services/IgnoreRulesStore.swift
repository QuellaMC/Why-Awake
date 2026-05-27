import Foundation

public protocol IgnoreRulesStoring: AnyObject {
    func rules() -> [IgnoreRule]
    func add(_ rule: IgnoreRule)
    func remove(id: IgnoreRule.ID)
}

public final class InMemoryIgnoreRulesStore: IgnoreRulesStoring {
    private var storage: [IgnoreRule]

    public init(rules: [IgnoreRule] = []) {
        storage = rules
    }

    public func rules() -> [IgnoreRule] {
        storage
    }

    public func add(_ rule: IgnoreRule) {
        guard !storage.contains(where: { $0.id == rule.id }) else { return }
        storage.append(rule)
    }

    public func remove(id: IgnoreRule.ID) {
        storage.removeAll { $0.id == id }
    }
}

public final class UserDefaultsIgnoreRulesStore: IgnoreRulesStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "ignoreRules") {
        self.defaults = defaults
        self.key = key
    }

    public func rules() -> [IgnoreRule] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([IgnoreRule].self, from: data)) ?? []
    }

    public func add(_ rule: IgnoreRule) {
        var next = rules()
        guard !next.contains(where: { $0.id == rule.id }) else { return }
        next.append(rule)
        save(next)
    }

    public func remove(id: IgnoreRule.ID) {
        save(rules().filter { $0.id != id })
    }

    private func save(_ rules: [IgnoreRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: key)
    }
}
