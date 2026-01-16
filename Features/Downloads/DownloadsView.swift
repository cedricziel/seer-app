import DownloadClient
import SeerUI
import SwiftUI

/// Main view for displaying and managing downloaded media
struct DownloadsView: View {
    @Environment(DownloadManager.self) private var downloadManager: DownloadManager?

    @State private var showSettings = false
    @State private var selectedDownload: Download?

    var body: some View {
        NavigationStack {
            Group {
                if let manager = downloadManager {
                    downloadsList(manager: manager)
                } else {
                    LoadingView(message: "Loading downloads...")
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                DownloadSettingsView()
            }
        }
    }

    @ViewBuilder
    private func downloadsList(manager: DownloadManager) -> some View {
        if manager.downloads.isEmpty {
            emptyState
        } else {
            List {
                activeDownloadsSection(manager: manager)
                waitingForWiFiSection(manager: manager)
                pendingDownloadsSection(manager: manager)
                pausedDownloadsSection(manager: manager)
                completedDownloadsSection(manager: manager)
                failedDownloadsSection(manager: manager)
                storageInfoSection(manager: manager)
            }
            .refreshable {
                await manager.refresh()
            }
        }
    }

    @ViewBuilder
    private func activeDownloadsSection(manager: DownloadManager) -> some View {
        if !manager.activeDownloads.isEmpty {
            Section("Downloading") {
                ForEach(manager.activeDownloads, id: \.id) { download in
                    DownloadRow(download: download, manager: manager)
                }
            }
        }
    }

    @ViewBuilder
    private func pendingDownloadsSection(manager: DownloadManager) -> some View {
        let pendingDownloads = manager.downloads.filter { $0.state == .pending }
        if !pendingDownloads.isEmpty {
            Section("Waiting") {
                ForEach(pendingDownloads, id: \.id) { download in
                    DownloadRow(download: download, manager: manager)
                }
            }
        }
    }

    @ViewBuilder
    private func waitingForWiFiSection(manager: DownloadManager) -> some View {
        if !manager.waitingForWiFiDownloads.isEmpty {
            Section {
                ForEach(manager.waitingForWiFiDownloads, id: \.id) { download in
                    DownloadRow(download: download, manager: manager)
                }
            } header: {
                Label("Waiting for WiFi", systemImage: "wifi.exclamationmark")
            } footer: {
                Text("These downloads will resume when connected to WiFi.")
            }
        }
    }

    @ViewBuilder
    private func pausedDownloadsSection(manager: DownloadManager) -> some View {
        let pausedDownloads = manager.downloads.filter { $0.state == .paused }
        if !pausedDownloads.isEmpty {
            Section("Paused") {
                ForEach(pausedDownloads, id: \.id) { download in
                    DownloadRow(download: download, manager: manager)
                }
            }
        }
    }

    @ViewBuilder
    private func completedDownloadsSection(manager: DownloadManager) -> some View {
        if !manager.completedDownloads.isEmpty {
            let movies = manager.completedDownloads.filter { $0.mediaType == "Movie" }
            let episodes = manager.completedDownloads.filter { $0.mediaType == "Episode" }

            if !movies.isEmpty {
                Section("Movies") {
                    ForEach(movies, id: \.id) { download in
                        DownloadRow(download: download, manager: manager)
                    }
                    .onDelete { indexSet in
                        deleteDownloads(at: indexSet, from: movies, manager: manager)
                    }
                }
            }

            if !episodes.isEmpty {
                let grouped = Dictionary(grouping: episodes) { $0.seriesName ?? "Unknown" }
                ForEach(grouped.keys.sorted(), id: \.self) { seriesName in
                    Section(seriesName) {
                        ForEach(grouped[seriesName]!, id: \.id) { download in
                            DownloadRow(download: download, manager: manager)
                        }
                        .onDelete { indexSet in
                            deleteDownloads(at: indexSet, from: grouped[seriesName]!, manager: manager)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func failedDownloadsSection(manager: DownloadManager) -> some View {
        let failedDownloads = manager.downloads.filter { $0.state == .failed }
        if !failedDownloads.isEmpty {
            Section("Failed") {
                ForEach(failedDownloads, id: \.id) { download in
                    DownloadRow(download: download, manager: manager)
                }
                .onDelete { indexSet in
                    deleteDownloads(at: indexSet, from: failedDownloads, manager: manager)
                }
            }
        }
    }

    private func storageInfoSection(manager: DownloadManager) -> some View {
        Section {
            HStack {
                Text("Total Downloaded")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: manager.totalDownloadedSize, countStyle: .file))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Downloads",
            systemImage: "arrow.down.circle",
            description: Text("Downloaded media will appear here for offline viewing.")
        )
    }

    private func deleteDownloads(at indexSet: IndexSet, from downloads: [Download], manager: DownloadManager) {
        Task {
            for index in indexSet {
                try? await manager.deleteDownload(downloads[index].id)
            }
        }
    }
}

/// Row view for a single download
struct DownloadRow: View {
    let download: Download
    let manager: DownloadManager
    var onPlay: (() -> Void)?
    var onShowInLibrary: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageURLString = download.primaryImageURL,
               let imageURL = URL(string: imageURLString) {
                PosterImage(url: imageURL, cornerRadius: 8)
                    .frame(width: 60, height: 90)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 90)
                    .overlay {
                        Image(systemName: download.mediaType == "Movie" ? "film" : "tv")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(download.name)
                    .font(.headline)
                    .lineLimit(2)

                if let seriesName = download.seriesName,
                   let season = download.seasonNumber,
                   let episode = download.episodeNumber {
                    Text("\(seriesName) • S\(season)E\(episode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(download.state.displayName)
                        .font(.caption)
                        .foregroundStyle(stateColor)

                    if download.state == .completed {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(download.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if download.state == .downloading {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(download.formattedProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if download.state == .downloading {
                    ProgressView(value: download.progress)
                        .tint(.accentColor)
                }
            }

            Spacer()

            CompactDownloadButton(
                state: buttonState,
                onDownload: handleDownloadAction,
                onCancel: handleCancelAction
            )
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    try? await manager.deleteDownload(download.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            downloadContextMenu
        }
    }

    @ViewBuilder
    private var downloadContextMenu: some View {
        // Play (completed only)
        if download.state == .completed, let onPlay {
            Button {
                onPlay()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
        }

        // Pause (downloading only)
        if download.state == .downloading {
            Button {
                Task {
                    try? await manager.pauseDownload(download.id)
                }
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
        }

        // Resume (paused only)
        if download.state == .paused {
            Button {
                Task {
                    try? await manager.resumeDownload(download.id)
                }
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
        }

        // Retry (failed only)
        if download.state == .failed {
            Button {
                Task {
                    try? await manager.resumeDownload(download.id)
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }

        // Cancel (pending, downloading, paused, or waiting for WiFi)
        if download.state == .pending || download.state == .downloading || download.state == .paused || download
            .state == .waitingForWiFi {
            Button(role: .destructive) {
                Task {
                    try? await manager.deleteDownload(download.id)
                }
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }

        // Show in Library
        if let onShowInLibrary {
            Divider()

            Button {
                onShowInLibrary()
            } label: {
                Label("Show in Library", systemImage: "folder")
            }
        }

        // Delete (all states)
        Divider()

        Button(role: .destructive) {
            Task {
                try? await manager.deleteDownload(download.id)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var buttonState: DownloadButtonState {
        switch download.state {
        case .pending:
            .pending
        case .downloading:
            .downloading(progress: download.progress)
        case .paused:
            .paused
        case .waitingForWiFi:
            .waitingForWiFi
        case .completed:
            .completed
        case .failed:
            .failed
        }
    }

    private var stateColor: Color {
        switch download.state {
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

    private func handleDownloadAction() {
        Task {
            switch download.state {
            case .paused, .failed:
                try? await manager.resumeDownload(download.id)
            default:
                break
            }
        }
    }

    private func handleCancelAction() {
        Task {
            if download.state == .downloading {
                try? await manager.pauseDownload(download.id)
            }
        }
    }
}

#Preview {
    DownloadsView()
}
