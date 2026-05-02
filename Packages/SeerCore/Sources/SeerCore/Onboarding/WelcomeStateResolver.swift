import Foundation

/// A single suggestion the welcome screen can render — either an iCloud-
/// synced server or a Bonjour-discovered server. The view doesn't care
/// about the provenance beyond `source` (used for the SF Symbol and
/// disclosure copy); resolver-internal types stay opaque.
public struct WelcomeSuggestion: Sendable, Equatable, Identifiable {
    public enum Source: Sendable, Equatable {
        case synced
        case bonjour
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let source: Source
    public let symbolName: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        source: Source,
        symbolName: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.source = source
        self.symbolName = symbolName
    }
}

/// What the welcome screen should render. Computed by `WelcomeStateResolver`
/// from the current set of synced and Bonjour servers.
public struct WelcomeState: Sendable, Equatable {
    public enum Primary: Sendable, Equatable {
        case manualEntry
        case suggestion(WelcomeSuggestion)
    }

    public let primary: Primary
    public let secondary: [WelcomeSuggestion]

    public init(primary: Primary, secondary: [WelcomeSuggestion]) {
        self.primary = primary
        self.secondary = secondary
    }

    public var hasSuggestions: Bool {
        if case .suggestion = primary { return true }
        return !secondary.isEmpty
    }
}

/// Pure function: given the current synced + Bonjour suggestion lists,
/// returns the welcome screen's primary call-to-action and secondary list.
///
/// Priority: synced server > Bonjour-discovered server > manual entry.
public struct WelcomeStateResolver: Sendable {
    public init() {}

    public func resolve(
        synced: [WelcomeSuggestion],
        bonjour: [WelcomeSuggestion]
    ) -> WelcomeState {
        let prioritized = synced + bonjour
        guard let primary = prioritized.first else {
            return WelcomeState(primary: .manualEntry, secondary: [])
        }
        return WelcomeState(
            primary: .suggestion(primary),
            secondary: Array(prioritized.dropFirst())
        )
    }
}
