import SwiftUI

/// Manual server URL entry path on the welcome screen. Validation lives in
/// the caller (typically a ServerInfoFetcher round-trip); this view just
/// surfaces in-flight state and inline errors.
public struct ManualServerEntryView: View {
    @Binding public var url: String
    public let isValidating: Bool
    public let errorMessage: String?
    public let onContinue: () -> Void

    public init(
        url: Binding<String>,
        isValidating: Bool,
        errorMessage: String?,
        onContinue: @escaping () -> Void
    ) {
        _url = url
        self.isValidating = isValidating
        self.errorMessage = errorMessage
        self.onContinue = onContinue
    }

    public var body: some View {
        Form {
            introSection
            serverSection
            if let error = errorMessage {
                errorSection(error)
            }
            actionSection
        }
        .navigationTitle("Add Server")
        .modifier(InlineNavigationTitleIfAvailable())
    }

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Connect to Jellyfin")
                    .font(.headline)
                Text(
                    "Enter your Jellyfin server's URL. We'll learn your "
                        + "internal address automatically once you're signed in."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var serverSection: some View {
        Section("Server URL") {
            TextField("https://jellyfin.example.com", text: $url)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .modifier(URLKeyboardIfAvailable())
                .modifier(NoAutocapitalizationIfAvailable())
                .accessibilityIdentifier("manual.url")
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("manual.errorBanner")
        }
    }

    private var actionSection: some View {
        Section {
            Button(action: onContinue) {
                HStack {
                    if isValidating {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(isValidating ? "Checking…" : "Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
            .accessibilityIdentifier("manual.continue")
        }
    }
}

// MARK: - Cross-platform shims (iOS-only modifiers)

private struct InlineNavigationTitleIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content.navigationBarTitleDisplayMode(.inline)
        #else
            content
        #endif
    }
}

private struct URLKeyboardIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content.keyboardType(.URL)
        #else
            content
        #endif
    }
}

private struct NoAutocapitalizationIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content.textInputAutocapitalization(.never)
        #else
            content
        #endif
    }
}

#Preview("Empty") {
    NavigationStack {
        ManualServerEntryView(
            url: .constant(""),
            isValidating: false,
            errorMessage: nil,
            onContinue: {}
        )
    }
}

#Preview("With error") {
    NavigationStack {
        ManualServerEntryView(
            url: .constant("https://not-jellyfin.example.com"),
            isValidating: false,
            errorMessage: "This URL doesn't look like a Jellyfin server.",
            onContinue: {}
        )
    }
}
