import Foundation

// MARK: - BackgroundSessionDelegate

extension DownloadManager: BackgroundSessionDelegate {
    public nonisolated func downloadDidProgress(
        taskIdentifier: Int,
        progress: Double,
        bytesWritten: Int64,
        totalBytes: Int64
    ) {
        Task { @MainActor [weak self] in
            guard let self, let downloadID = await resolveDownloadID(forTask: taskIdentifier) else { return }
            try? await store.updateProgress(
                downloadID: downloadID,
                progress: progress,
                bytesDownloaded: bytesWritten,
                totalBytes: totalBytes
            )
            await refresh()
        }
    }

    public nonisolated func downloadDidComplete(taskIdentifier: Int, tempFileURL: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let downloadID = await resolveDownloadID(forTask: taskIdentifier) else {
                // Nothing in the store refers to this task; the file is orphaned.
                try? FileManager.default.removeItem(at: tempFileURL)
                return
            }
            await finalizeDownload(downloadID: downloadID, tempFileURL: tempFileURL)
        }
    }

    /// Resolve a URLSession task to a download. Prefers the session manager's
    /// in-memory map; falls back to the persisted `Download.taskIdentifier`,
    /// which is the only source of truth after a background relaunch.
    func resolveDownloadID(forTask taskIdentifier: Int) async -> UUID? {
        if let downloadID = sessionManager.downloadID(forTask: taskIdentifier) {
            return downloadID
        }
        guard let download = try? await store.fetchDownload(taskIdentifier: taskIdentifier) else {
            return nil
        }
        sessionManager.registerTask(taskIdentifier, forDownload: download.id)
        return download.id
    }

    /// Move a fully downloaded file from its pending location into permanent
    /// storage and mark the download completed. Shared by the live delegate
    /// path and the launch-time reconciliation in `requeuePendingDownloads`.
    func finalizeDownload(downloadID: UUID, tempFileURL: URL) async {
        guard let download = try? await store.fetchDownload(id: downloadID) else {
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
            try await store.updateTaskIdentifier(downloadID: downloadID, taskIdentifier: nil)
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

    public nonisolated func downloadDidFail(taskIdentifier: Int, error: Error, resumeData: Data?) {
        Task { @MainActor [weak self] in
            guard let self, let downloadID = await resolveDownloadID(forTask: taskIdentifier) else { return }

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
