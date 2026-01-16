import SwiftUI

/// The current state of a download for UI display
public enum DownloadButtonState: Sendable, Equatable {
    case notDownloaded
    case pending
    case downloading(progress: Double)
    case paused
    case waitingForWiFi
    case completed
    case failed
}

/// A styled button for downloading media with progress indication
public struct DownloadButton: View {
    public let state: DownloadButtonState
    public let onDownload: () -> Void
    public let onPause: () -> Void
    public let onResume: () -> Void
    public let onCancel: () -> Void
    public let onDelete: () -> Void

    public init(
        state: DownloadButtonState,
        onDownload: @escaping () -> Void,
        onPause: @escaping () -> Void = {},
        onResume: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onDownload = onDownload
        self.onPause = onPause
        self.onResume = onResume
        self.onCancel = onCancel
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: primaryAction) {
            HStack {
                stateIcon
                Text(stateText)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(state == .pending || state == .waitingForWiFi)
        .contextMenu {
            contextMenuItems
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var primaryAction: () -> Void {
        switch state {
        case .notDownloaded:
            onDownload
        case .pending, .waitingForWiFi:
            {} // Disabled
        case .downloading:
            onPause
        case .paused:
            onResume
        case .completed:
            onDelete
        case .failed:
            onDownload // Retry
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
        case .pending:
            ProgressView()
                .tint(foregroundColor)
        case let .downloading(progress):
            ZStack {
                Circle()
                    .stroke(lineWidth: 2)
                    .opacity(0.3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
        case .paused:
            Image(systemName: "pause.circle")
        case .waitingForWiFi:
            Image(systemName: "wifi.exclamationmark")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.circle")
        }
    }

    private var stateText: String {
        switch state {
        case .notDownloaded:
            "Download"
        case .pending:
            "Waiting..."
        case let .downloading(progress):
            "\(Int(progress * 100))%"
        case .paused:
            "Paused"
        case .waitingForWiFi:
            "Waiting for WiFi"
        case .completed:
            "Downloaded"
        case .failed:
            "Retry"
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .notDownloaded:
            .accentColor
        case .pending, .downloading, .paused:
            .secondary.opacity(0.2)
        case .waitingForWiFi:
            .orange.opacity(0.2)
        case .completed:
            .green.opacity(0.2)
        case .failed:
            .red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .notDownloaded:
            .white
        case .pending, .downloading, .paused:
            .primary
        case .waitingForWiFi:
            .orange
        case .completed:
            .green
        case .failed:
            .red
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        switch state {
        case .notDownloaded:
            EmptyView()
        case .pending, .waitingForWiFi:
            Button("Cancel", role: .destructive, action: onCancel)
        case .downloading:
            Button("Pause", action: onPause)
            Button("Cancel", role: .destructive, action: onCancel)
        case .paused:
            Button("Resume", action: onResume)
            Button("Cancel", role: .destructive, action: onCancel)
        case .completed:
            Button("Delete Download", role: .destructive, action: onDelete)
        case .failed:
            Button("Retry", action: onDownload)
            Button("Dismiss", role: .destructive, action: onCancel)
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .notDownloaded:
            "Download"
        case .pending:
            "Download pending"
        case .downloading:
            "Downloading"
        case .paused:
            "Download paused"
        case .waitingForWiFi:
            "Waiting for WiFi"
        case .completed:
            "Downloaded"
        case .failed:
            "Download failed"
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .notDownloaded:
            "Not downloaded"
        case .pending:
            "Waiting to start"
        case let .downloading(progress):
            "\(Int(progress * 100)) percent complete"
        case .paused:
            "Tap to resume"
        case .waitingForWiFi:
            "Will resume on WiFi"
        case .completed:
            "Ready to watch offline"
        case .failed:
            "Tap to retry"
        }
    }

    private var accessibilityHint: String {
        switch state {
        case .notDownloaded:
            "Double tap to start download"
        case .pending, .waitingForWiFi:
            "Long press for options"
        case .downloading:
            "Double tap to pause, long press for more options"
        case .paused:
            "Double tap to resume, long press for more options"
        case .completed:
            "Double tap to delete, long press for options"
        case .failed:
            "Double tap to retry, long press to dismiss"
        }
    }
}

/// A compact download button for use in list rows
public struct CompactDownloadButton: View {
    public let state: DownloadButtonState
    public let onDownload: () -> Void
    public let onCancel: () -> Void

    public init(
        state: DownloadButtonState,
        onTap: @escaping () -> Void
    ) {
        self.state = state
        onDownload = onTap
        onCancel = {}
    }

    public init(
        state: DownloadButtonState,
        onDownload: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.state = state
        self.onDownload = onDownload
        self.onCancel = onCancel
    }

    public var body: some View {
        Button(action: onDownload) {
            stateIcon
                .font(.title2)
                .foregroundStyle(iconColor)
        }
        .buttonStyle(.plain)
        .disabled(state == .pending || state == .waitingForWiFi)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
        case .pending:
            ProgressView()
        case let .downloading(progress):
            ZStack {
                Circle()
                    .stroke(lineWidth: 2.5)
                    .opacity(0.3)
                    .frame(width: 24, height: 24)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 24, height: 24)
                Image(systemName: "pause.fill")
                    .font(.caption2)
            }
        case .paused:
            Image(systemName: "pause.circle.fill")
        case .waitingForWiFi:
            Image(systemName: "wifi.exclamationmark.circle.fill")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
        }
    }

    private var iconColor: Color {
        switch state {
        case .notDownloaded:
            .accentColor
        case .pending, .downloading, .paused:
            .secondary
        case .waitingForWiFi:
            .orange
        case .completed:
            .green
        case .failed:
            .red
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .notDownloaded:
            "Download"
        case .pending:
            "Download pending"
        case .downloading:
            "Downloading"
        case .paused:
            "Download paused"
        case .waitingForWiFi:
            "Waiting for WiFi"
        case .completed:
            "Downloaded"
        case .failed:
            "Download failed"
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .notDownloaded:
            "Not downloaded"
        case .pending:
            "Waiting to start"
        case let .downloading(progress):
            "\(Int(progress * 100)) percent complete"
        case .paused:
            "Paused"
        case .waitingForWiFi:
            "Will resume on WiFi"
        case .completed:
            "Ready offline"
        case .failed:
            "Failed"
        }
    }

    private var accessibilityHint: String {
        switch state {
        case .notDownloaded:
            "Double tap to download"
        case .pending, .waitingForWiFi:
            ""
        case .downloading:
            "Double tap to pause"
        case .paused:
            "Double tap to resume"
        case .completed:
            ""
        case .failed:
            "Double tap to retry"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DownloadButton(state: .notDownloaded, onDownload: {})
        DownloadButton(state: .pending, onDownload: {})
        DownloadButton(state: .downloading(progress: 0.45), onDownload: {})
        DownloadButton(state: .paused, onDownload: {})
        DownloadButton(state: .completed, onDownload: {})
        DownloadButton(state: .failed, onDownload: {})

        Divider()

        HStack(spacing: 30) {
            CompactDownloadButton(state: .notDownloaded, onDownload: {}, onCancel: {})
            CompactDownloadButton(state: .downloading(progress: 0.6), onDownload: {}, onCancel: {})
            CompactDownloadButton(state: .waitingForWiFi, onDownload: {}, onCancel: {})
            CompactDownloadButton(state: .completed, onDownload: {}, onCancel: {})
            CompactDownloadButton(state: .failed, onDownload: {}, onCancel: {})
        }
    }
    .padding()
}
