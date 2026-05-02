import Foundation

/// Persists recent search queries so users can re-issue them without retyping.
///
/// Backed by `UserDefaults` (not Keychain — these are non-sensitive). Keys are
/// scoped per server to avoid leaking history across multi-server households.
///
/// Not declared `Sendable` because `record(_:scope:)` and `remove(_:scope:)`
/// do unsynchronized read-modify-write against `UserDefaults`. Use from a
/// single actor (the view models hold this on `@MainActor`).
public final class SearchHistoryStore {
    /// Maximum number of recent queries kept per scope.
    public static let maxItems: Int = 10

    /// Minimum length of a query to be considered worth remembering.
    public static let minQueryLength: Int = 2

    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "seer.searchHistory") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    /// Returns recent queries for `scope` (most recent first).
    public func recentQueries(scope: String = "default") -> [String] {
        defaults.stringArray(forKey: storageKey(for: scope)) ?? []
    }

    /// Records a query at the front of the list, deduplicating case-insensitively
    /// and trimming the list to `maxItems`. Returns the updated list.
    @discardableResult
    public func record(_ rawQuery: String, scope: String = "default") -> [String] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minQueryLength else {
            return recentQueries(scope: scope)
        }

        var current = recentQueries(scope: scope)
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        current.insert(trimmed, at: 0)
        if current.count > Self.maxItems {
            current = Array(current.prefix(Self.maxItems))
        }
        defaults.set(current, forKey: storageKey(for: scope))
        return current
    }

    /// Removes a single query (case-insensitive match).
    @discardableResult
    public func remove(_ query: String, scope: String = "default") -> [String] {
        var current = recentQueries(scope: scope)
        current.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        defaults.set(current, forKey: storageKey(for: scope))
        return current
    }

    /// Clears all recent queries for the given scope.
    public func clear(scope: String = "default") {
        defaults.removeObject(forKey: storageKey(for: scope))
    }

    private func storageKey(for scope: String) -> String {
        "\(keyPrefix).\(scope)"
    }
}
