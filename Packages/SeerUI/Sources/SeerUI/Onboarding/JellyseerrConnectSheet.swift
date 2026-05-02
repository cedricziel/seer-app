import SwiftUI

/// View model backing `JellyseerrConnectSheet`. Pure UI state plus an
/// injected `connector` closure so SeerUI does not depend on JellyseerrClient
/// or AppState — the calling Feature owns the actual validation/persistence.
@MainActor
public final class JellyseerrConnectSheetModel: ObservableObject {
    public typealias Connector = @MainActor @Sendable (URL, String) async throws -> Void

    @Published public var url: String = ""
    @Published public var apiKey: String = ""
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    private let connector: Connector

    public init(connector: @escaping Connector) {
        self.connector = connector
    }

    public var isSubmittable: Bool {
        !url.trimmingCharacters(in: .whitespaces).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !isLoading
    }

    /// Returns true on success. On failure, leaves errorMessage populated and
    /// returns false; the caller should NOT dismiss.
    public func attemptConnect() async -> Bool {
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)

        guard let parsed = URL(string: trimmedURL),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              parsed.host != nil
        else {
            errorMessage = "Please enter a valid Jellyseerr URL (https://...)."
            return false
        }
        guard !trimmedKey.isEmpty else {
            errorMessage = "Please enter your API key."
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await connector(parsed, trimmedKey)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// Reusable sheet for connecting Jellyseerr from any feature surface
/// (Discover, Search "Request" tap, Requests tab). Validation and persistence
/// happen via the injected `connector`; the sheet only handles UI state.
public struct JellyseerrConnectSheet: View {
    @StateObject private var model: JellyseerrConnectSheetModel
    private let onSuccess: @MainActor () -> Void
    private let onCancel: @MainActor () -> Void

    public init(
        connector: @escaping JellyseerrConnectSheetModel.Connector,
        onSuccess: @escaping @MainActor () -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        _model = StateObject(wrappedValue: JellyseerrConnectSheetModel(connector: connector))
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                introSection
                serverSection
                apiKeySection
                if let error = model.errorMessage {
                    errorBanner(error)
                }
            }
            .navigationTitle("Connect Jellyseerr")
            .modifier(InlineNavigationTitleIfAvailable())
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "popcorn.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Browse and request media")
                    .font(.headline)
                Text(
                    "Connect Jellyseerr to discover trending titles and ask "
                        + "your server admin to add them to the library."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var serverSection: some View {
        Section("Jellyseerr URL") {
            TextField("https://jellyseerr.example.com", text: $model.url)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .modifier(URLKeyboardIfAvailable())
                .modifier(NoAutocapitalizationIfAvailable())
                .accessibilityIdentifier("jellyseerr.url")
        }
    }

    private var apiKeySection: some View {
        Section("API Key") {
            SecureField("API key", text: $model.apiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .modifier(NoAutocapitalizationIfAvailable())
                .accessibilityIdentifier("jellyseerr.apiKey")
            Text("Find this in Jellyseerr Settings > General.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("jellyseerr.errorBanner")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Maybe Later") { onCancel() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task {
                    if await model.attemptConnect() {
                        onSuccess()
                    }
                }
            } label: {
                if model.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("Connect")
                        .fontWeight(.semibold)
                }
            }
            .disabled(!model.isSubmittable)
        }
    }
}

// MARK: - Cross-platform modifier shims

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
    JellyseerrConnectSheet(
        connector: { _, _ in },
        onSuccess: {},
        onCancel: {}
    )
}

#Preview("Filled") {
    let sheet = JellyseerrConnectSheet(
        connector: { _, _ in
            try await Task.sleep(for: .milliseconds(500))
        },
        onSuccess: {},
        onCancel: {}
    )
    sheet
}
