import SwiftUI

/// Renders the 6-character Quick Connect code with instructions for
/// approving it on the Jellyfin web client. Pure presentation; the polling
/// loop and state lives in `JellyfinClient.QuickConnectSession`.
public struct QuickConnectView: View {
    public let code: String
    public let serverHost: String
    public let isPolling: Bool
    public let onUsePassword: () -> Void
    public let onCancel: () -> Void
    public let onCopyCode: () -> Void

    public init(
        code: String,
        serverHost: String,
        isPolling: Bool = true,
        onUsePassword: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onCopyCode: @escaping () -> Void
    ) {
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
                codeCard
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
            Text("Enter this code on \(serverHost)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var codeCard: some View {
        VStack(spacing: 16) {
            // HIG / Dynamic Type: scale relative to .largeTitle so AX text
            // sizes grow the code legibly; minimumScaleFactor protects
            // against overflow on iPhone landscape at AX5.
            Text(code)
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .tracking(8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel(spelledOutCode)
                .accessibilityIdentifier("quickconnect.code")

            Button {
                onCopyCode()
            } label: {
                Label("Copy code", systemImage: "doc.on.doc")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("quickconnect.copy")
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color.quickConnectCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            if isPolling {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Waiting for approval…")
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

    private var spelledOutCode: String {
        code.map { String($0) }.joined(separator: ", ")
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
        onCopyCode: {}
    )
}
