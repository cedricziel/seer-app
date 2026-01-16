import BackgroundTasks
import DownloadClient
import UIKit

/// App delegate for handling background URL session callbacks and background tasks
final class SeerAppDelegate: NSObject, UIApplicationDelegate {
    /// Reference to the download manager (set by SeerApp)
    weak var downloadManager: DownloadManager?

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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
}
