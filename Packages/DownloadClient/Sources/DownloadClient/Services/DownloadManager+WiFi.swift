import Foundation

// MARK: - WiFi-Only Downloads

public extension DownloadManager {
    /// Downloads waiting for WiFi
    var waitingForWiFiDownloads: [Download] {
        downloads.filter { $0.state == .waitingForWiFi }
    }

    /// Set WiFi-only downloads setting
    func setWiFiOnlyEnabled(_ enabled: Bool) async {
        guard wifiOnlyEnabled != enabled else { return }
        let wasPaused = await queue.queuePaused
        await queue.pauseQueue()
        wifiOnlyEnabled = enabled
        await queue.setWiFiOnlyEnabled(enabled)

        // Existing background requests retain their original cellular policy.
        await pauseDownloadsForWiFi()
        let isOnWiFi = await queue.isWiFiConnected
        if !enabled || isOnWiFi {
            await resumeWiFiWaitingDownloads()
        }
        if !wasPaused {
            await queue.resumeQueue()
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
        startClaims.invalidateAll()
        let downloads = await (try? store.fetchAllDownloads()) ?? []
        for download in downloads where download.state == .downloading || download.state == .pending {
            startClaims.invalidate(download.id)
            let taskIdentifier = download.taskIdentifier
            try? await store.updateState(downloadID: download.id, state: .waitingForWiFi)
            if let taskIdentifier {
                sessionManager.unregisterTask(taskIdentifier)
                let resumeData = await sessionManager.cancelDownload(taskIdentifier: taskIdentifier)
                if let resumeData {
                    try? await store.updateResumeData(downloadID: download.id, resumeData: resumeData)
                }
            }
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
