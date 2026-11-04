import SwiftUI

/// State-aware welcome screen for first-run onboarding.
/// SeerUI stays free of SeerCore: callers map their domain types into
/// `WelcomeView.Suggestion` instances before constructing the view.
public struct WelcomeView: View {
    public struct Suggestion: Identifiable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let symbolName: String

        public init(id: String, title: String, subtitle: String, symbolName: String) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.symbolName = symbolName
        }
    }

    public let primarySuggestion: Suggestion?
    public let secondarySuggestions: [Suggestion]
    public let onSelectSuggestion: (Suggestion) -> Void
    public let onManualEntry: () -> Void

    /// HIG: Increase Contrast adds a visible 1pt accent border to the
    /// secondary suggestion rows so the visual hierarchy stays legible
    /// without relying on opacity.
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    /// Identifier for the initial focus target on tvOS. The Siri Remote
    /// lands here when the welcome screen appears.
    private static let manualEntryFocusID = "welcome.manualEntry"

    @FocusState private var focusedID: String?

    private var defaultFocusID: String {
        primarySuggestion?.id ?? Self.manualEntryFocusID
    }

    public init(
        primarySuggestion: Suggestion?,
        secondarySuggestions: [Suggestion] = [],
        onSelectSuggestion: @escaping (Suggestion) -> Void,
        onManualEntry: @escaping () -> Void
    ) {
        self.primarySuggestion = primarySuggestion
        self.secondarySuggestions = secondarySuggestions
        self.onSelectSuggestion = onSelectSuggestion
        self.onManualEntry = onManualEntry
    }

    public var body: some View {
        GeometryReader { geometry in
            Group {
                if geometry.size.width > geometry.size.height {
                    horizontalBody
                } else {
                    verticalBody
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.welcomeBackground)
        .defaultFocus($focusedID, defaultFocusID)
    }

    private var verticalBody: some View {
        ScrollView {
            VStack(spacing: 32) {
                hero
                suggestionList
                footer
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
    }

    private var horizontalBody: some View {
        HStack(spacing: 0) {
            // Leading 40% — hero
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                hero
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            // Trailing 60% — suggestions + footer in a stack
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        suggestionList
                            .padding(.top, 24)
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity)
                }
                footer
                    .padding()
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.welcomeBackground)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityIgnoresInvertColors(true)
                .accessibilityHidden(true)
            Text("Welcome to Seer")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Stream from your Jellyfin library, on any device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var suggestionList: some View {
        if let primary = primarySuggestion {
            VStack(spacing: 12) {
                suggestionRow(primary, emphasized: true)
                ForEach(secondarySuggestions) { suggestion in
                    suggestionRow(suggestion, emphasized: false)
                }
            }
        } else {
            // Fresh-install / no-suggestion state. Manual entry is the only
            // path; the footer handles it. Render a hint card so the screen
            // doesn't feel empty.
            emptyStateHint
        }
    }

    private func suggestionRow(_ suggestion: Suggestion, emphasized: Bool) -> some View {
        Button {
            onSelectSuggestion(suggestion)
        } label: {
            suggestionRowLabel(suggestion, emphasized: emphasized)
        }
        .buttonStyle(.plain)
        .focused($focusedID, equals: suggestion.id)
        .accessibilityElement(children: .combine)
    }

    private func suggestionRowLabel(_ suggestion: Suggestion, emphasized: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: suggestion.symbolName)
                .font(.title2)
                .foregroundStyle(emphasized ? Color.white : Color.accentColor)
                .frame(width: 36, height: 36)
                .background(emphasized ? Color.accentColor : Color.welcomeIconBackground)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(suggestion.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color.welcomeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor(emphasized: emphasized), lineWidth: borderWidth(emphasized: emphasized))
        )
    }

    private func borderColor(emphasized: Bool) -> Color {
        if emphasized {
            return Color.accentColor.opacity(0.6)
        }
        // Increase Contrast: outline secondary rows so they don't rely on a
        // subtle background fill alone for affordance.
        return colorSchemeContrast == .increased ? Color.primary.opacity(0.5) : Color.clear
    }

    private func borderWidth(emphasized: Bool) -> CGFloat {
        if emphasized { return 2 }
        return colorSchemeContrast == .increased ? 1 : 0
    }

    private var emptyStateHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("No servers found nearby")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Enter your server's address below to connect manually.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.welcomeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var footer: some View {
        let label = Text(primarySuggestion == nil ? "Enter Server URL" : "Add a server manually")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)

        if primarySuggestion == nil {
            Button(action: onManualEntry) { label }
            #if os(tvOS)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            #else
                .buttonStyle(WelcomeProminentButtonStyle())
            #endif
                .focused($focusedID, equals: Self.manualEntryFocusID)
                .accessibilityIdentifier(Self.manualEntryFocusID)
        } else {
            Button(action: onManualEntry) { label }
            #if os(tvOS)
                .buttonStyle(.bordered)
            #else
                .buttonStyle(WelcomePlainButtonStyle())
            #endif
                .focused($focusedID, equals: Self.manualEntryFocusID)
                .accessibilityIdentifier(Self.manualEntryFocusID)
        }
    }
}

// MARK: - Cross-platform colors

private extension Color {
    static var welcomeBackground: Color {
        #if os(iOS)
            Color(uiColor: .systemGroupedBackground)
        #else
            Color.gray.opacity(0.08)
        #endif
    }

    static var welcomeCardBackground: Color {
        #if os(iOS)
            Color(uiColor: .secondarySystemGroupedBackground)
        #else
            Color.gray.opacity(0.15)
        #endif
    }

    static var welcomeIconBackground: Color {
        #if os(iOS)
            Color(uiColor: .systemBackground)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}

// MARK: - Button styles

private struct WelcomeProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.accentColor)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct WelcomePlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .foregroundStyle(Color.accentColor)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#Preview("Fresh install") {
    WelcomeView(
        primarySuggestion: nil,
        secondarySuggestions: [],
        onSelectSuggestion: { _ in },
        onManualEntry: {}
    )
}

#Preview("With suggestion") {
    WelcomeView(
        primarySuggestion: WelcomeView.Suggestion(
            id: "1",
            title: "Mac mini",
            subtitle: "macmini.local · on this Wi-Fi",
            symbolName: "wifi"
        ),
        secondarySuggestions: [
            WelcomeView.Suggestion(
                id: "2",
                title: "Synology NAS",
                subtitle: "synced via iCloud",
                symbolName: "icloud.fill"
            )
        ],
        onSelectSuggestion: { _ in },
        onManualEntry: {}
    )
}
