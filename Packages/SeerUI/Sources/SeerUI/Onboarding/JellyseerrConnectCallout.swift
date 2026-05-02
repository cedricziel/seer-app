import SwiftUI

/// Empty-state callout that prompts the user to connect Jellyseerr from
/// any feature surface (Discover, Search, Requests). Pure presentation —
/// the calling Feature owns sheet presentation and credential persistence.
public struct JellyseerrConnectCallout: View {
    public let title: String
    public let description: String
    public let onConnectTapped: () -> Void

    public init(
        title: String,
        description: String,
        onConnectTapped: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.onConnectTapped = onConnectTapped
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "popcorn.fill")
        } description: {
            Text(description)
                .multilineTextAlignment(.center)
        } actions: {
            Button("Connect Jellyseerr", action: onConnectTapped)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("jellyseerr.connectButton")
        }
        .accessibilityIdentifier("jellyseerr.connectCallout")
    }
}

#Preview {
    JellyseerrConnectCallout(
        title: "Discover Movies & Shows",
        description: "Connect Jellyseerr to browse trending content and request new media.",
        onConnectTapped: {}
    )
}
