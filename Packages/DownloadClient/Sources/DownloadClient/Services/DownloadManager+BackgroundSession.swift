import Foundation

// MARK: - BackgroundSessionDelegate

extension DownloadManager: BackgroundSessionDelegate {
    public nonisolated func downloadDidProgress(
        taskIdentifier: Int,
        progress: Double,
        bytesWritten: Int64,
        totalBytes: Int64
    ) {
        guard let downloadID = sessionManager.downloadID(forTask: taskIdentifier) else { return }

        Task { @MainActor [weak self] in
            try? await self?.store.updateProgress(
                downloadID: downloadID,
                progress: progress,
                bytesDownloaded: bytesWritten,
                totalBytes: totalBytes
            )
            await self?.refresh()
        }
    }

    public nonisolated func downloadDidComplete(taskIdentifier: Int, tempFileURL: URL) {
        guard let downloadID = sessionManager.downloadID(forTask: taskIdentifier) else { return }

        Task { @MainActor [weak self] in
            guard let self,
                  let download = try? await store.fetchDownload(id: downloadID)
            else {
                // Clean up intermediate file if we can't process the download
                try? FileManager.default.removeItem(at: tempFileURL)
                return
            }

            do {
                // Move file from intermediate location to permanent location
                let relativePath = try await storage.moveDownloadedFile(
                    from: tempFileURL,
                    serverID: download.serverID,
                    mediaType: download.mediaType,
                    itemID: download.itemID,
                    fileName: "\(download.itemID).mp4"
                )

                // Update download record
                try await store.updateFilePath(downloadID: downloadID, relativePath: relativePath)
                try await store.updateState(downloadID: downloadID, state: .completed)

                // Notify delegate for notifications
                await notificationDelegate?.downloadDidComplete(
                    downloadID: downloadID,
                    title: download.displayTitle,
                    serverID: download.serverID,
                    isAutoDownload: false // Auto-download tracking to be added
                )

                await queue.markCompleted(downloadID)
                await refresh()
            } catch {
                // Clean up intermediate file on failure
                try? FileManager.default.removeItem(at: tempFileURL)

                try? await store.updateState(
                    downloadID: downloadID,
                    state: .failed,
                    errorMessage: error.localizedDescription
                )

                // Notify delegate about failure
                await notificationDelegate?.downloadDidFail(
                    downloadID: downloadID,
                    title: download.displayTitle,
                    errorMessage: error.localizedDescription,
                    serverID: download.serverID
                )

                await queue.markCompleted(downloadID)
                await refresh()
            }
        }
    }

    public nonisolated func downloadDidFail(taskIdentifier: Int, error: Error, resumeData: Data?) {
        guard let downloadID = sessionManager.downloadID(forTask: taskIdentifier) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            // Save resume data if available
            if let resumeData {
                try? await store.updateResumeData(downloadID: downloadID, resumeData: resumeData)
                try? await store.updateState(downloadID: downloadID, state: .paused)
            } else {
                // Get download info for notification
                let download = try? await store.fetchDownload(id: downloadID)

                try? await store.updateState(
                    downloadID: downloadID,
                    state: .failed,
                    errorMessage: error.localizedDescription
                )

                // Notify delegate about failure (only when no resume data - real failure)
                if let download {
                    await notificationDelegate?.downloadDidFail(
                        downloadID: downloadID,
                        title: download.displayTitle,
                        errorMessage: error.localizedDescription,
                        serverID: download.serverID
                    )
                }
            }

            await queue.markCompleted(downloadID)
            await refresh()
        }
    }

    public nonisolated func allTasksCompleted() {
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }
}
