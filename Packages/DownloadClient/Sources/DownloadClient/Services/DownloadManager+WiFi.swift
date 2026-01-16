import Foundation

// MARK: - WiFi-Only Downloads

public extension DownloadManager {
    /// Downloads waiting for WiFi
    var waitingForWiFiDownloads: [Download] {
        downloads.filter { $0.state == .waitingForWiFi }
    }

    /// Set WiFi-only downloads setting
    func setWiFiOnlyEnabled(_ enabled: Bool) async {
        wifiOnlyEnabled = enabled
        await queue.setWiFiOnlyEnabled(enabled)

        if enabled {
            // If enabling WiFi-only and not on WiFi, pause active downloads
            let isOnWiFi = await queue.isWiFiConnected
            if !isOnWiFi {
                await pauseDownloadsForWiFi()
            }
        } else {
            // If disabling WiFi-only, resume waiting downloads
            await resumeWiFiWaitingDownloads()
        }
    }

    /// Whether WiFi-only downloads is enabled
    var isWiFiOnlyEnabled: Bool {
        wifiOnlyEnabled
    }

    /// Whether downloads are blocked waiting for WiFi
    var isBlockedByWiFiOnly: Bool {
        get async { await queue.isBlockedByWiFiOnly }
    }

    /// Pause active downloads and mark them as waiting for WiFi
    internal func pauseDownloadsForWiFi() async {
        for download in downloads where download.state == .downloading || download.state == .pending {
            // Cancel active task if any
            if let taskIdentifier = download.taskIdentifier {
                let resumeData = await sessionManager.cancelDownload(taskIdentifier: taskIdentifier)
                if let resumeData {
                    try? await store.updateResumeData(downloadID: download.id, resumeData: resumeData)
                }
            }

            // Update state to waiting for WiFi
            try? await store.updateState(downloadID: download.id, state: .waitingForWiFi)
            await queue.dequeue(download.id)
        }

        await refresh()
    }

    /// Resume downloads that were waiting for WiFi
    internal func resumeWiFiWaitingDownloads() async {
        for download in downloads where download.state == .waitingForWiFi {
            // Update state back to pending and re-queue
            try? await store.updateState(downloadID: download.id, state: .pending)
            await queue.enqueue(download.id)
        }

        await refresh()
    }

    /// Handle network status changes
    internal func handleNetworkStatusChanged(isConnected: Bool, isOnWiFi: Bool) async {
        guard wifiOnlyEnabled else { return }

        if isConnected, isOnWiFi {
            // WiFi available - resume waiting downloads
            await resumeWiFiWaitingDownloads()
        } else if isConnected, !isOnWiFi {
            // On cellular - pause downloads for WiFi
            await pauseDownloadsForWiFi()
        }
    }
}
