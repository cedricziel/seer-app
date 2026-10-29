import SwiftUI

/// Displays a Quick Connect code or recovery actions when a request fails.
/// A nil code represents a request in progress; an error hides any unusable code.
public struct QuickConnectView: View {
    @State private var copiedCode: String?

    public let code: String?
    public let serverHost: String
    public let errorMessage: String?
    public let onRetry: () -> Void
    public let isPolling: Bool
    public let onUsePassword: () -> Void
    public let onCancel: () -> Void
    public let onCopyCode: () -> Bool

    public init(
        code: String?,
        serverHost: String,
        isPolling: Bool = true,
        errorMessage: String? = nil,
        onRetry: @escaping () -> Void = {},
        onUsePassword: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onCopyCode: @escaping () -> Bool
    ) {
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.code = code
        self.serverHost = serverHost
        self.isPolling = isPolling
        self.onUsePassword = onUsePassword
        self.onCancel = onCancel
        self.onCopyCode = onCopyCode
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                    .padding(.top, 24)
                if let code, errorMessage == nil {
                    codeCard(code: code)
                }
                statusRow
                actions
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color.quickConnectBackground)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityIgnoresInvertColors(true)
                .accessibilityHidden(true)
            Text("Quick Connect")
                .font(.title)
                .fontWeight(.bold)
            Text(code != nil && errorMessage == nil
                ? "Enter this code on \(serverHost)"
                : "Sign in to \(serverHost)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func codeCard(code: String) -> some View {
        VStack(spacing: 16) {
            // HIG / Dynamic Type: scale relative to .largeTitle so AX text
            // sizes grow the code legibly; minimumScaleFactor protects
            // against overflow on iPhone landscape at AX5.
            Text(code)
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .tracking(8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel(code.map { String($0) }.joined(separator: ", "))
                .accessibilityIdentifier("quickconnect.code")

            #if !os(tvOS)
                Button {
                    if onCopyCode() {
                        copiedCode = code
                    }
                } label: {
                    Label(
                        copiedCode == code ? "Copied" : "Copy code",
                        systemImage: copiedCode == code ? "checkmark" : "doc.on.doc"
                    )
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("quickconnect.copy")
            #endif
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color.quickConnectCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            if let errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(errorMessage)
                    .font(.subheadline)
                    .accessibilityIdentifier("quickconnect.error")
            } else if isPolling {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(code == nil ? "Requesting code…" : "Waiting for approval…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
                Text("Polling paused")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if errorMessage != nil {
                Button("Request New Code", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("quickconnect.retry")
            }

            Button("Use Password Instead", action: onUsePassword)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("quickconnect.usePassword")

            Button(role: .cancel, action: onCancel) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("quickconnect.cancel")
        }
    }
}

// MARK: - Cross-platform colors

private extension Color {
    static var quickConnectBackground: Color {
        #if os(iOS)
            Color(uiColor: .systemGroupedBackground)
        #else
            Color.gray.opacity(0.08)
        #endif
    }

    static var quickConnectCardBackground: Color {
        #if os(iOS)
            Color(uiColor: .secondarySystemGroupedBackground)
        #else
            Color.gray.opacity(0.15)
        #endif
    }
}

#Preview("Polling") {
    QuickConnectView(
        code: "473819",
        serverHost: "macmini.local",
        isPolling: true,
        onUsePassword: {},
        onCancel: {},
        onCopyCode: { true }
    )
}
