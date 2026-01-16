import SwiftUI

/// Configuration for media item context menu actions
public struct MediaContextMenuConfig {
    public var canPlay: Bool
    public var canDownload: Bool
    public var isDownloaded: Bool
    public var isWatched: Bool
    public var showDetailsOption: Bool

    public init(
        canPlay: Bool = false,
        canDownload: Bool = false,
        isDownloaded: Bool = false,
        isWatched: Bool = false,
        showDetailsOption: Bool = false
    ) {
        self.canPlay = canPlay
        self.canDownload = canDownload
        self.isDownloaded = isDownloaded
        self.isWatched = isWatched
        self.showDetailsOption = showDetailsOption
    }
}

/// Actions that can be performed from a media context menu
public struct MediaContextMenuActions {
    public var onPlay: (() -> Void)?
    public var onDownload: (() -> Void)?
    public var onDeleteDownload: (() -> Void)?
    public var onToggleWatched: ((Bool) -> Void)?
    public var onShowDetails: (() -> Void)?

    public init(
        onPlay: (() -> Void)? = nil,
        onDownload: (() -> Void)? = nil,
        onDeleteDownload: (() -> Void)? = nil,
        onToggleWatched: ((Bool) -> Void)? = nil,
        onShowDetails: (() -> Void)? = nil
    ) {
        self.onPlay = onPlay
        self.onDownload = onDownload
        self.onDeleteDownload = onDeleteDownload
        self.onToggleWatched = onToggleWatched
        self.onShowDetails = onShowDetails
    }
}

/// A view modifier that adds a context menu for media items
public struct MediaContextMenuModifier: ViewModifier {
    let config: MediaContextMenuConfig
    let actions: MediaContextMenuActions

    public init(config: MediaContextMenuConfig, actions: MediaContextMenuActions) {
        self.config = config
        self.actions = actions
    }

    public func body(content: Content) -> some View {
        content
            .contextMenu {
                contextMenuContent
            }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        // Play action
        if config.canPlay, let onPlay = actions.onPlay {
            Button {
                onPlay()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
        }

        // Download/Delete Download action
        if config.isDownloaded {
            if let onDeleteDownload = actions.onDeleteDownload {
                Button(role: .destructive) {
                    onDeleteDownload()
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            }
        } else if config.canDownload, let onDownload = actions.onDownload {
            Button {
                onDownload()
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
        }

        // Watch status toggle
        if let onToggleWatched = actions.onToggleWatched {
            Divider()

            if config.isWatched {
                Button {
                    onToggleWatched(false)
                } label: {
                    Label("Mark as Unwatched", systemImage: "eye.slash")
                }
            } else {
                Button {
                    onToggleWatched(true)
                } label: {
                    Label("Mark as Watched", systemImage: "eye")
                }
            }
        }

        // View details
        if config.showDetailsOption, let onShowDetails = actions.onShowDetails {
            Divider()

            Button {
                onShowDetails()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }
    }
}

/// Configuration for download item context menu
public struct DownloadContextMenuConfig {
    public var isCompleted: Bool
    public var isDownloading: Bool
    public var isPaused: Bool
    public var isPending: Bool
    public var isFailed: Bool

    public init(
        isCompleted: Bool = false,
        isDownloading: Bool = false,
        isPaused: Bool = false,
        isPending: Bool = false,
        isFailed: Bool = false
    ) {
        self.isCompleted = isCompleted
        self.isDownloading = isDownloading
        self.isPaused = isPaused
        self.isPending = isPending
        self.isFailed = isFailed
    }
}

/// Actions for download context menu
public struct DownloadContextMenuActions {
    public var onPlay: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onResume: (() -> Void)?
    public var onCancel: (() -> Void)?
    public var onDelete: (() -> Void)?
    public var onShowInLibrary: (() -> Void)?

    public init(
        onPlay: (() -> Void)? = nil,
        onPause: (() -> Void)? = nil,
        onResume: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onShowInLibrary: (() -> Void)? = nil
    ) {
        self.onPlay = onPlay
        self.onPause = onPause
        self.onResume = onResume
        self.onCancel = onCancel
        self.onDelete = onDelete
        self.onShowInLibrary = onShowInLibrary
    }
}

/// A view modifier for download item context menus
public struct DownloadContextMenuModifier: ViewModifier {
    let config: DownloadContextMenuConfig
    let actions: DownloadContextMenuActions

    public init(config: DownloadContextMenuConfig, actions: DownloadContextMenuActions) {
        self.config = config
        self.actions = actions
    }

    public func body(content: Content) -> some View {
        content
            .contextMenu {
                contextMenuContent
            }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        // Play (completed only)
        if config.isCompleted, let onPlay = actions.onPlay {
            Button {
                onPlay()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
        }

        // Pause (downloading only)
        if config.isDownloading, let onPause = actions.onPause {
            Button {
                onPause()
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
        }

        // Resume (paused only)
        if config.isPaused, let onResume = actions.onResume {
            Button {
                onResume()
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
        }

        // Cancel (pending, downloading, or paused)
        if config.isPending || config.isDownloading || config.isPaused, let onCancel = actions.onCancel {
            Button(role: .destructive) {
                onCancel()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }

        // Show in Library
        if let onShowInLibrary = actions.onShowInLibrary {
            Divider()

            Button {
                onShowInLibrary()
            } label: {
                Label("Show in Library", systemImage: "folder")
            }
        }

        // Delete (all states)
        if let onDelete = actions.onDelete {
            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Actions for request context menu
public struct RequestContextMenuActions {
    public var onViewDetails: (() -> Void)?
    public var onCancelRequest: (() -> Void)?

    public init(
        onViewDetails: (() -> Void)? = nil,
        onCancelRequest: (() -> Void)? = nil
    ) {
        self.onViewDetails = onViewDetails
        self.onCancelRequest = onCancelRequest
    }
}

/// A view modifier for request item context menus
public struct RequestContextMenuModifier: ViewModifier {
    let canCancel: Bool
    let actions: RequestContextMenuActions

    public init(canCancel: Bool, actions: RequestContextMenuActions) {
        self.canCancel = canCancel
        self.actions = actions
    }

    public func body(content: Content) -> some View {
        content
            .contextMenu {
                contextMenuContent
            }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        // View Details
        if let onViewDetails = actions.onViewDetails {
            Button {
                onViewDetails()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }

        // Cancel Request
        if canCancel, let onCancelRequest = actions.onCancelRequest {
            Divider()

            Button(role: .destructive) {
                onCancelRequest()
            } label: {
                Label("Cancel Request", systemImage: "xmark.circle")
            }
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Adds a context menu for media items with play, download, and watch status actions
    func mediaContextMenu(
        config: MediaContextMenuConfig,
        actions: MediaContextMenuActions
    ) -> some View {
        modifier(MediaContextMenuModifier(config: config, actions: actions))
    }

    /// Adds a context menu for download items with pause, resume, cancel, and delete actions
    func downloadContextMenu(
        config: DownloadContextMenuConfig,
        actions: DownloadContextMenuActions
    ) -> some View {
        modifier(DownloadContextMenuModifier(config: config, actions: actions))
    }

    /// Adds a context menu for request items with view details and cancel actions
    func requestContextMenu(
        canCancel: Bool,
        actions: RequestContextMenuActions
    ) -> some View {
        modifier(RequestContextMenuModifier(canCancel: canCancel, actions: actions))
    }
}
