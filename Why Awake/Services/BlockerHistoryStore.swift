import Foundation

public protocol BlockerHistoryStoring: AnyObject {
    func record(_ blockers: [SleepBlocker], at date: Date)
    func entries() -> [BlockerHistoryEntry]
    func clear()
}

public final class InMemoryBlockerHistoryStore: BlockerHistoryStoring {
    private var storage: [String: BlockerHistoryEntry] = [:]
    private var activeIDs: Set<String> = []

    public init(entries: [BlockerHistoryEntry] = []) {
        for entry in entries {
            storage[entry.id] = entry
        }
    }

    public func record(_ blockers: [SleepBlocker], at date: Date) {
        let currentIDs = Set(blockers.map { BlockerHistoryEntry.identity(for: $0) })

        for blocker in blockers {
            let id = BlockerHistoryEntry.identity(for: blocker)
            if var entry = storage[id] {
                entry.lastSeen = date
                if !activeIDs.contains(id) {
                    entry.occurrences += 1
                }
                storage[id] = entry
            } else {
                storage[id] = BlockerHistoryEntry(blocker: blocker, at: date)
            }
        }

        activeIDs = currentIDs
    }

    public func entries() -> [BlockerHistoryEntry] {
        storage.values.sorted { lhs, rhs in
            if lhs.lastSeen != rhs.lastSeen {
                return lhs.lastSeen > rhs.lastSeen
            }
            return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending
        }
    }

    public func clear() {
        storage.removeAll()
        activeIDs.removeAll()
    }
}

public final class UserDefaultsBlockerHistoryStore: BlockerHistoryStoring {
    private let defaults: UserDefaults
    private let key: String
    private let activeKey: String

    public init(defaults: UserDefaults = .standard, key: String = "blockerHistory") {
        self.defaults = defaults
        self.key = key
        activeKey = "\(key).activeIDs"
    }

    public func record(_ blockers: [SleepBlocker], at date: Date) {
        var storage = Dictionary(uniqueKeysWithValues: entries().map { ($0.id, $0) })
        let previousActiveIDs = activeIDs()
        let currentIDs = Set(blockers.map { BlockerHistoryEntry.identity(for: $0) })

        for blocker in blockers {
            let id = BlockerHistoryEntry.identity(for: blocker)
            if var entry = storage[id] {
                entry.lastSeen = date
                if !previousActiveIDs.contains(id) {
                    entry.occurrences += 1
                }
                storage[id] = entry
            } else {
                storage[id] = BlockerHistoryEntry(blocker: blocker, at: date)
            }
        }

        save(Array(storage.values))
        saveActiveIDs(currentIDs)
    }

    public func entries() -> [BlockerHistoryEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([BlockerHistoryEntry].self, from: data)) ?? []
    }

    public func clear() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: activeKey)
    }

    private func save(_ entries: [BlockerHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    private func activeIDs() -> Set<String> {
        guard let values = defaults.array(forKey: activeKey) as? [String] else { return [] }
        return Set(values)
    }

    private func saveActiveIDs(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: activeKey)
    }
}
