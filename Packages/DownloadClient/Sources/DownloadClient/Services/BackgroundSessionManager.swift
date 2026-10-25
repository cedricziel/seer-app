import Foundation

/// Delegate protocol for background session events
public protocol BackgroundSessionDelegate: AnyObject, Sendable {
    func downloadDidProgress(taskIdentifier: Int, progress: Double, bytesWritten: Int64, totalBytes: Int64)
    func downloadDidComplete(taskIdentifier: Int, tempFileURL: URL)
    func downloadDidFail(taskIdentifier: Int, error: Error, resumeData: Data?)
    func allTasksCompleted()
}

/// Manager for background URLSession downloads
public final class BackgroundSessionManager: NSObject, @unchecked Sendable {
    /// Shared instance
    public static let shared = BackgroundSessionManager()

    /// Background session identifier
    public static let sessionIdentifier = "com.cedricziel.seer.download"

    /// The background URLSession
    public private(set) var session: URLSession

    /// Delegate for download events (thread-safe access via lock)
    private weak var _delegate: BackgroundSessionDelegate?
    private let delegateLock = NSLock()

    public var delegate: BackgroundSessionDelegate? {
        get {
            delegateLock.lock()
            defer { delegateLock.unlock() }
            return _delegate
        }
        set {
            delegateLock.lock()
            defer { delegateLock.unlock() }
            _delegate = newValue
        }
    }

    /// Completion handler from UIApplication (not Sendable - from UIKit delegate)
    private var _backgroundCompletionHandler: (() -> Void)?
    private let completionHandlerLock = NSLock()

    private var backgroundCompletionHandler: (() -> Void)? {
        get {
            completionHandlerLock.lock()
            defer { completionHandlerLock.unlock() }
            return _backgroundCompletionHandler
        }
        set {
            completionHandlerLock.lock()
            defer { completionHandlerLock.unlock() }
            _backgroundCompletionHandler = newValue
        }
    }

    /// Active download tasks mapped by identifier
    private let activeTasks = NSLock()
    private var _taskMap: [Int: UUID] = [:]

    private var taskMap: [Int: UUID] {
        get {
            activeTasks.lock()
            defer { activeTasks.unlock() }
            return _taskMap
        }
        set {
            activeTasks.lock()
            defer { activeTasks.unlock() }
            _taskMap = newValue
        }
    }

    override private init() {
        // Use a temporary shared session for the stored property requirement before super.init()
        session = URLSession.shared

        super.init()

        // Now create the real background session with self as delegate
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60 // 7 days
        config.httpMaximumConnectionsPerHost = 2

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Create a properly configured background session
    public static func createSession(delegate: URLSessionDelegate?) -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60 // 7 days
        config.httpMaximumConnectionsPerHost = 2

        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    // MARK: - Task Management

    /// Start a download task
    public func startDownload(
        url: URL,
        downloadID: UUID,
        headers: [String: String] = [:]
    ) -> URLSessionDownloadTask {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.downloadTask(with: request)
        taskMap[task.taskIdentifier] = downloadID
        task.resume()

        return task
    }

    /// Resume a download with saved data
    public func resumeDownload(
        resumeData: Data,
        downloadID: UUID
    ) -> URLSessionDownloadTask {
        let task = session.downloadTask(withResumeData: resumeData)
        taskMap[task.taskIdentifier] = downloadID
        task.resume()

        return task
    }

    /// Cancel a download task
    public func cancelDownload(taskIdentifier: Int, saveResumeData: Bool = true) async -> Data? {
        guard let task = await findTask(identifier: taskIdentifier) else { return nil }

        if saveResumeData {
            return await withCheckedContinuation { continuation in
                task.cancel { data in
                    continuation.resume(returning: data)
                }
            }
        } else {
            task.cancel()
            return nil
        }
    }

    /// Find a task by identifier
    private func findTask(identifier: Int) async -> URLSessionDownloadTask? {
        let tasks = await session.allTasks
        return tasks.compactMap { $0 as? URLSessionDownloadTask }
            .first { $0.taskIdentifier == identifier }
    }

    /// Get download ID for a task
    public func downloadID(forTask taskIdentifier: Int) -> UUID? {
        taskMap[taskIdentifier]
    }

    /// Register a download ID for a task
    public func registerTask(_ taskIdentifier: Int, forDownload downloadID: UUID) {
        taskMap[taskIdentifier] = downloadID
    }

    /// Unregister a task
    public func unregisterTask(_ taskIdentifier: Int) {
        taskMap[taskIdentifier] = nil
    }

    // MARK: - Background Handling

    /// Set the background completion handler (called from UIApplicationDelegate)
    public func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        backgroundCompletionHandler = handler
    }

    /// Call the background completion handler
    fileprivate func callBackgroundCompletionHandler() {
        DispatchQueue.main.async { [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }

    // MARK: - Session Recovery

    /// Recover tasks after app launch
    public func recoverTasks() async -> [(taskIdentifier: Int, downloadURL: URL?)] {
        let tasks = await session.allTasks
        return tasks.compactMap { task -> (Int, URL?)? in
            guard let downloadTask = task as? URLSessionDownloadTask else { return nil }
            return (downloadTask.taskIdentifier, downloadTask.originalRequest?.url)
        }
    }

    /// Get all currently active task identifiers
    public func activeTaskIdentifiers() async -> Set<Int> {
        let tasks = await session.allTasks
        return Set(tasks.map(\.taskIdentifier))
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundSessionManager: URLSessionDownloadDelegate {
    public func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        // Progress callbacks are too frequent to log

        delegate?.downloadDidProgress(
            taskIdentifier: downloadTask.taskIdentifier,
            progress: progress,
            bytesWritten: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        )
    }

    public func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        print("[Download] Complete: task \(downloadTask.taskIdentifier)")

        // The in-memory task map is empty when iOS relaunches the app in the
        // background to deliver this event. The file must still be preserved
        // SYNCHRONOUSLY (the system deletes `location` once this returns), so
        // fall back to a task-identifier-keyed name that the download manager
        // can reconcile against the persisted `Download.taskIdentifier`.
        let downloadID = downloadID(forTask: downloadTask.taskIdentifier)
        if downloadID == nil {
            print("[Download] No in-memory download ID for task \(downloadTask.taskIdentifier); preserving by task")
        }

        let intermediateURL = moveToIntermediateLocation(
            tempURL: location,
            downloadID: downloadID,
            taskIdentifier: downloadTask.taskIdentifier
        )

        delegate?.downloadDidComplete(
            taskIdentifier: downloadTask.taskIdentifier,
            tempFileURL: intermediateURL ?? location // Pass intermediate URL if move succeeded
        )

        unregisterTask(downloadTask.taskIdentifier)
    }

    // MARK: - Pending (completed-but-unprocessed) files

    /// Directory that holds files the URLSession has finished downloading but
    /// the `DownloadManager` has not yet moved into the downloads folder. Lives
    /// in Application Support rather than `tmp` so it survives until the app
    /// next has a chance to reconcile (e.g. after a background relaunch).
    public static var pendingDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PendingDownloads", isDirectory: true)
    }

    /// Location a completed file is parked at when its download ID is known.
    public static func pendingFileURL(forDownload downloadID: UUID) -> URL {
        pendingDirectory.appendingPathComponent("download-\(downloadID.uuidString).tmp")
    }

    /// Location a completed file is parked at when only the URLSession task
    /// identifier is known (background relaunch before the manager exists).
    public static func pendingFileURL(forTask taskIdentifier: Int) -> URL {
        pendingDirectory.appendingPathComponent("download-task-\(taskIdentifier).tmp")
    }

    /// Move temp file to a safe intermediate location synchronously
    /// Returns the new URL if successful, nil if failed
    private func moveToIntermediateLocation(tempURL: URL, downloadID: UUID?, taskIdentifier: Int) -> URL? {
        let fileManager = FileManager.default
        let intermediateURL = if let downloadID {
            Self.pendingFileURL(forDownload: downloadID)
        } else {
            Self.pendingFileURL(forTask: taskIdentifier)
        }

        do {
            try fileManager.createDirectory(at: Self.pendingDirectory, withIntermediateDirectories: true)
            // Remove any existing file at intermediate location
            if fileManager.fileExists(atPath: intermediateURL.path) {
                try fileManager.removeItem(at: intermediateURL)
            }
            try fileManager.moveItem(at: tempURL, to: intermediateURL)
            print("[Download] Moved temp file to intermediate location: \(intermediateURL.lastPathComponent)")
            return intermediateURL
        } catch {
            print("[Download] Failed to move to intermediate location: \(error.localizedDescription)")
            return nil
        }
    }

    public func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }
        print("[Download] Failed: task \(task.taskIdentifier) - \(error.localizedDescription)")

        var resumeData: Data?
        if let urlError = error as? URLError {
            resumeData = urlError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        }

        delegate?.downloadDidFail(
            taskIdentifier: task.taskIdentifier,
            error: error,
            resumeData: resumeData
        )

        unregisterTask(task.taskIdentifier)
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
        delegate?.allTasksCompleted()
        callBackgroundCompletionHandler()
    }
}

// MARK: - URLSessionDelegate

extension BackgroundSessionManager: URLSessionDelegate {
    public func urlSession(
        _: URLSession,
        didBecomeInvalidWithError error: (any Error)?
    ) {
        if let error {
            print("Background session invalidated: \(error.localizedDescription)")
        }
    }
}
