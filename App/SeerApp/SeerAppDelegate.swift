import BackgroundTasks
import DownloadClient
import NotificationClient
import SeerCore
import UIKit

/// App delegate for handling background URL session callbacks and background tasks
final class SeerAppDelegate: NSObject, UIApplicationDelegate {
    /// Reference to the download manager (set by SeerApp)
    weak var downloadManager: DownloadManager?

    /// Reference to the notification manager (set by SeerApp)
    var notificationManager: NotificationManager?

    /// Reference to the request status poller (set by SeerApp)
    var requestStatusPoller: RequestStatusPoller?

    /// Background task identifier for request status polling
    static let requestPollTaskIdentifier = "com.cedricziel.seer.requestpoll"

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize TelemetryService for OpenTelemetry-based performance and crash diagnostics
        _ = TelemetryService.shared

        // Register background tasks
        registerBackgroundTasks()
        return true
    }

    // MARK: - Background URL Session Handling

    func application(
        _: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Handle background URL session events for downloads
        if identifier == BackgroundSessionManager.sessionIdentifier {
            BackgroundSessionManager.shared.setBackgroundCompletionHandler(completionHandler)
        }
    }

    // MARK: - Background Task Registration

    private func registerBackgroundTasks() {
        // Register auto-download background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AutoDownloadService.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self?.handleAutoDownloadTask(processingTask)
        }

        // Register request status polling background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.requestPollTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self?.handleRequestPollTask(processingTask)
        }
    }

    private func handleAutoDownloadTask(_ task: BGProcessingTask) {
        // Schedule the next occurrence
        scheduleAutoDownloadTask()

        // Create a task to process auto-downloads
        let processingTask = Task {
            // Auto-download processing would happen here
            // For now, just complete the task
            task.setTaskCompleted(success: true)
        }

        // Handle task expiration
        task.expirationHandler = {
            processingTask.cancel()
        }
    }

    private func handleRequestPollTask(_ task: BGProcessingTask) {
        // Schedule the next occurrence
        scheduleRequestPollTask()

        // Create a task to poll for request status changes
        let processingTask = Task { [weak self] in
            guard let poller = self?.requestStatusPoller else {
                task.setTaskCompleted(success: true)
                return
            }

            await poller.poll()
            task.setTaskCompleted(success: true)
        }

        // Handle task expiration
        task.expirationHandler = {
            processingTask.cancel()
        }
    }

    /// Schedule the auto-download background task
    func scheduleAutoDownloadTask() {
        let request = BGProcessingTaskRequest(identifier: AutoDownloadService.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule auto-download task: \(error)")
        }
    }

    /// Schedule the request status polling background task
    func scheduleRequestPollTask() {
        let request = BGProcessingTaskRequest(identifier: Self.requestPollTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule request poll task: \(error)")
        }
    }
}

// MARK: - NotificationActionDelegate

extension SeerAppDelegate: NotificationActionDelegate {
    @MainActor
    func didTapNotification(category: NotificationCategory, info: NotificationInfo) {
        // Handle notification tap - navigate to appropriate screen
        // Deep linking can be implemented based on category and info
        print("[SeerAppDelegate] Notification tapped: \(category), info: \(info)")
    }

    @MainActor
    func didTapRetryDownload(downloadID: UUID) {
        // Retry the failed download
        Task {
            do {
                try await downloadManager?.resumeDownload(downloadID)
            } catch {
                print("[SeerAppDelegate] Failed to retry download: \(error)")
            }
        }
    }

    @MainActor
    func didTapCancelDownload(downloadID: UUID) {
        // Cancel/delete the failed download
        Task {
            do {
                try await downloadManager?.cancelDownload(downloadID)
            } catch {
                print("[SeerAppDelegate] Failed to cancel download: \(error)")
            }
        }
    }
}
