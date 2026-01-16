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
    public let session: URLSession

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
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60 // 7 days
        config.httpMaximumConnectionsPerHost = 2

        // Create session with a temporary delegate
        let tempSession = URLSession(configuration: config)
        session = tempSession

        super.init()

        // Now set self as delegate
        let finalConfig = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        finalConfig.isDiscretionary = false
        finalConfig.sessionSendsLaunchEvents = true
        finalConfig.allowsCellularAccess = true
        finalConfig.waitsForConnectivity = true
        finalConfig.timeoutIntervalForResource = 7 * 24 * 60 * 60
        finalConfig.httpMaximumConnectionsPerHost = 2

        // Note: We can't reassign session since it's let
        // The session delegate will be set up via the session's delegate property
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
        delegate?.downloadDidComplete(
            taskIdentifier: downloadTask.taskIdentifier,
            tempFileURL: location
        )

        unregisterTask(downloadTask.taskIdentifier)
    }

    public func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }

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
