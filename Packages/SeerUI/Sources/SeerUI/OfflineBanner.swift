import SwiftUI

/// A banner that displays when the app is in offline mode
public struct OfflineBanner: View {
    public let isOffline: Bool
    public let lastSyncDate: Date?
    public let onRefresh: (() -> Void)?

    public init(
        isOffline: Bool,
        lastSyncDate: Date? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.isOffline = isOffline
        self.lastSyncDate = lastSyncDate
        self.onRefresh = onRefresh
    }

    public var body: some View {
        if isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let lastSyncDate {
                        Text("Last synced \(lastSyncDate, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Showing cached content")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let onRefresh {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// A smaller inline indicator for cached data
public struct CachedDataIndicator: View {
    public let isShowingCachedData: Bool
    public let lastSyncDate: Date?

    public init(isShowingCachedData: Bool, lastSyncDate: Date? = nil) {
        self.isShowingCachedData = isShowingCachedData
        self.lastSyncDate = lastSyncDate
    }

    public var body: some View {
        if isShowingCachedData {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption2)

                if let lastSyncDate {
                    Text("Cached \(lastSyncDate, style: .relative) ago")
                        .font(.caption2)
                } else {
                    Text("Cached")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }
}

/// A sync status view for settings
public struct SyncStatusView: View {
    public let isSyncing: Bool
    public let lastSyncDate: Date?
    public let pendingChangesCount: Int
    public let onSyncNow: () -> Void

    public init(
        isSyncing: Bool,
        lastSyncDate: Date?,
        pendingChangesCount: Int,
        onSyncNow: @escaping () -> Void
    ) {
        self.isSyncing = isSyncing
        self.lastSyncDate = lastSyncDate
        self.pendingChangesCount = pendingChangesCount
        self.onSyncNow = onSyncNow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync Status")
                        .font(.headline)

                    if let lastSyncDate {
                        Text("Last synced \(lastSyncDate, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Sync Now", action: onSyncNow)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                }
            }

            if pendingChangesCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)

                    Text("\(pendingChangesCount) pending change\(pendingChangesCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Offline Banner") {
    VStack(spacing: 20) {
        OfflineBanner(
            isOffline: true,
            lastSyncDate: Date().addingTimeInterval(-3600)
        ) {
            print("Refresh tapped")
        }

        OfflineBanner(
            isOffline: true,
            lastSyncDate: nil
        )

        OfflineBanner(isOffline: false)
    }
    .padding()
}

#Preview("Cached Indicator") {
    VStack(spacing: 20) {
        CachedDataIndicator(
            isShowingCachedData: true,
            lastSyncDate: Date().addingTimeInterval(-1800)
        )

        CachedDataIndicator(
            isShowingCachedData: true
        )

        CachedDataIndicator(isShowingCachedData: false)
    }
}

#Preview("Sync Status") {
    VStack(spacing: 20) {
        SyncStatusView(
            isSyncing: false,
            lastSyncDate: Date().addingTimeInterval(-7200),
            pendingChangesCount: 3
        ) {
            print("Sync tapped")
        }

        SyncStatusView(
            isSyncing: true,
            lastSyncDate: Date().addingTimeInterval(-7200),
            pendingChangesCount: 0
        ) {}
    }
    .padding()
}
