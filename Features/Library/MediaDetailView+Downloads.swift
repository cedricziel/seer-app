import DownloadClient
import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

// MARK: - Download Methods Extension

extension MediaDetailView {
    // MARK: - Item Download Methods

    func startDownload() async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials
        else { return }

        do {
            try await manager.downloadItem(item, serverID: credentials.serverURL.host ?? "default")
            await updateDownloadState()
        } catch {
            // Handle error
        }
    }

    func pauseDownload() async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials,
              let download = await manager.download(
                  forItemID: item.id,
                  serverID: credentials.serverURL.host ?? "default"
              )
        else { return }

        try? await manager.pauseDownload(download.id)
        await updateDownloadState()
    }

    func resumeDownload() async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials,
              let download = await manager.download(
                  forItemID: item.id,
                  serverID: credentials.serverURL.host ?? "default"
              )
        else { return }

        try? await manager.resumeDownload(download.id)
        await updateDownloadState()
    }

    func cancelDownload() async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials,
              let download = await manager.download(
                  forItemID: item.id,
                  serverID: credentials.serverURL.host ?? "default"
              )
        else { return }

        try? await manager.cancelDownload(download.id)
        await updateDownloadState()
    }

    func deleteDownload() async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials,
              let download = await manager.download(
                  forItemID: item.id,
                  serverID: credentials.serverURL.host ?? "default"
              )
        else { return }

        try? await manager.deleteDownload(download.id)
        await updateDownloadState()
    }

    @MainActor
    func updateDownloadState() async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials
        else {
            downloadState = .notDownloaded
            return
        }

        let serverID = credentials.serverURL.host ?? "default"

        if let download = await manager.download(forItemID: item.id, serverID: serverID) {
            switch download.state {
            case .pending:
                downloadState = .pending
            case .downloading:
                downloadState = .downloading(progress: download.progress)
            case .paused:
                downloadState = .paused
            case .waitingForWiFi:
                downloadState = .waitingForWiFi
            case .completed:
                downloadState = .completed
            case .failed:
                downloadState = .failed
            }
        } else {
            downloadState = .notDownloaded
        }
    }

    // MARK: - Episode Download Methods

    func downloadEpisode(_ episode: MediaItem) async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials
        else { return }

        let serverID = credentials.serverURL.host ?? "default"
        do {
            try await manager.downloadItem(episode, serverID: serverID)
            await updateEpisodeDownloadStates(episodes: [episode])
        } catch {
            print("Failed to download episode: \(error)")
        }
    }

    func downloadSeason(episodes: [MediaItem]) async {
        for episode in episodes {
            await downloadEpisode(episode)
        }
    }

    func updateEpisodeDownloadStates(episodes: [MediaItem]) async {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials
        else { return }

        let serverID = credentials.serverURL.host ?? "default"
        for episode in episodes {
            if let download = await manager.download(forItemID: episode.id, serverID: serverID) {
                switch download.state {
                case .pending:
                    episodeDownloadStates[episode.id] = .pending
                case .downloading:
                    episodeDownloadStates[episode.id] = .downloading(progress: download.progress)
                case .paused:
                    episodeDownloadStates[episode.id] = .paused
                case .waitingForWiFi:
                    episodeDownloadStates[episode.id] = .waitingForWiFi
                case .completed:
                    episodeDownloadStates[episode.id] = .completed
                case .failed:
                    episodeDownloadStates[episode.id] = .failed
                }
            } else {
                episodeDownloadStates[episode.id] = .notDownloaded
            }
        }
    }

    /// Get download state for an episode directly from downloadManager (reactive)
    func downloadStateFor(episodeID: String) -> DownloadButtonState {
        guard let manager = downloadManager,
              let credentials = appState.jellyfinCredentials
        else { return .notDownloaded }

        let serverID = credentials.serverURL.host ?? "default"
        guard let download = manager.downloads.first(where: {
            $0.itemID == episodeID && $0.serverID == serverID
        }) else {
            return .notDownloaded
        }

        switch download.state {
        case .pending: return .pending
        case .downloading: return .downloading(progress: download.progress)
        case .paused: return .paused
        case .waitingForWiFi: return .waitingForWiFi
        case .completed: return .completed
        case .failed: return .failed
        }
    }
}
