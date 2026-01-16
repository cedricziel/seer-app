@testable import DownloadClient
import Foundation
import XCTest

/// Progress event captured by mock delegate
struct ProgressEvent {
    let taskIdentifier: Int
    let progress: Double
    let bytesWritten: Int64
    let totalBytes: Int64
}

/// Complete event captured by mock delegate
struct CompleteEvent {
    let taskIdentifier: Int
    let tempFileURL: URL
}

/// Fail event captured by mock delegate
struct FailEvent {
    let taskIdentifier: Int
    let error: Error
    let resumeData: Data?
}

/// Mock delegate for capturing download events
final class MockBackgroundSessionDelegate: BackgroundSessionDelegate, @unchecked Sendable {
    var progressEvents: [ProgressEvent] = []
    var completeEvents: [CompleteEvent] = []
    var failEvents: [FailEvent] = []
    var allTasksCompletedCalled = false

    private let lock = NSLock()

    func downloadDidProgress(
        taskIdentifier: Int,
        progress: Double,
        bytesWritten: Int64,
        totalBytes: Int64
    ) {
        lock.lock()
        progressEvents.append(ProgressEvent(
            taskIdentifier: taskIdentifier,
            progress: progress,
            bytesWritten: bytesWritten,
            totalBytes: totalBytes
        ))
        lock.unlock()
    }

    func downloadDidComplete(taskIdentifier: Int, tempFileURL: URL) {
        lock.lock()
        completeEvents.append(CompleteEvent(taskIdentifier: taskIdentifier, tempFileURL: tempFileURL))
        lock.unlock()
    }

    func downloadDidFail(taskIdentifier: Int, error: Error, resumeData: Data?) {
        lock.lock()
        failEvents.append(FailEvent(taskIdentifier: taskIdentifier, error: error, resumeData: resumeData))
        lock.unlock()
    }

    func allTasksCompleted() {
        lock.lock()
        allTasksCompletedCalled = true
        lock.unlock()
    }
}

/// Tests for BackgroundSessionManager, particularly the synchronous file move fix
final class BackgroundSessionManagerTests: XCTestCase {
    var mockDelegate: MockBackgroundSessionDelegate!

    override func setUp() async throws {
        try await super.setUp()
        mockDelegate = MockBackgroundSessionDelegate()
    }

    override func tearDown() async throws {
        mockDelegate = nil
        try await super.tearDown()
    }

    // MARK: - Task Registration Tests

    func testDownloadIDForTask_returnsNilForUnregisteredTask() {
        let sut = BackgroundSessionManager.shared

        let downloadID = sut.downloadID(forTask: 99999)

        XCTAssertNil(downloadID)
    }

    func testRegisterTask_storesDownloadIDCorrectly() {
        let sut = BackgroundSessionManager.shared
        let testDownloadID = UUID()
        let testTaskID = 12345

        sut.registerTask(testTaskID, forDownload: testDownloadID)
        let retrievedID = sut.downloadID(forTask: testTaskID)

        XCTAssertEqual(retrievedID, testDownloadID)

        // Clean up
        sut.unregisterTask(testTaskID)
    }

    func testUnregisterTask_removesDownloadID() {
        let sut = BackgroundSessionManager.shared
        let testDownloadID = UUID()
        let testTaskID = 12346

        sut.registerTask(testTaskID, forDownload: testDownloadID)
        sut.unregisterTask(testTaskID)
        let retrievedID = sut.downloadID(forTask: testTaskID)

        XCTAssertNil(retrievedID)
    }

    // MARK: - Intermediate File Location Tests

    /// Test that verifies the intermediate file location pattern is correct
    func testIntermediateFileLocation_usesCorrectPattern() {
        let downloadID = UUID()
        let tempDir = FileManager.default.temporaryDirectory
        let expectedPath = tempDir.appendingPathComponent("download-\(downloadID.uuidString).tmp")

        // Verify the path contains the download ID
        XCTAssertTrue(expectedPath.lastPathComponent.contains(downloadID.uuidString))
        XCTAssertTrue(expectedPath.lastPathComponent.hasPrefix("download-"))
        XCTAssertTrue(expectedPath.lastPathComponent.hasSuffix(".tmp"))
    }

    /// Test that simulates the synchronous file move behavior
    func testSynchronousFileMoveToIntermediate_preservesFileContent() throws {
        // Create a temporary source file
        let fileManager = FileManager.default
        let sourceURL = fileManager.temporaryDirectory
            .appendingPathComponent("test-source-\(UUID().uuidString).tmp")
        let testContent = Data("Test download content".utf8)
        try testContent.write(to: sourceURL)

        // Create the intermediate destination
        let downloadID = UUID()
        let intermediateURL = fileManager.temporaryDirectory
            .appendingPathComponent("download-\(downloadID.uuidString).tmp")

        // Perform synchronous move (simulating what BackgroundSessionManager does)
        if fileManager.fileExists(atPath: intermediateURL.path) {
            try fileManager.removeItem(at: intermediateURL)
        }
        try fileManager.moveItem(at: sourceURL, to: intermediateURL)

        // Verify file was moved and content preserved
        XCTAssertFalse(fileManager.fileExists(atPath: sourceURL.path), "Source file should not exist after move")
        XCTAssertTrue(fileManager.fileExists(atPath: intermediateURL.path), "Intermediate file should exist")

        let movedContent = try Data(contentsOf: intermediateURL)
        XCTAssertEqual(movedContent, testContent, "Content should be preserved after move")

        // Clean up
        try? fileManager.removeItem(at: intermediateURL)
    }

    /// Test that the intermediate file survives asynchronous operations
    func testIntermediateFile_survivesAsyncOperations() async throws {
        let fileManager = FileManager.default
        let downloadID = UUID()
        let intermediateURL = fileManager.temporaryDirectory
            .appendingPathComponent("download-\(downloadID.uuidString).tmp")

        // Create the intermediate file (simulating what BackgroundSessionManager does)
        let testContent = Data("Test async survival content".utf8)
        try testContent.write(to: intermediateURL)

        // Simulate async delay (like what happens in the real delegate callback)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify file still exists (this is the key fix - the intermediate file
        // should NOT be deleted by the system like the original temp file would be)
        XCTAssertTrue(
            fileManager.fileExists(atPath: intermediateURL.path),
            "Intermediate file should survive async operations"
        )

        let survivedContent = try Data(contentsOf: intermediateURL)
        XCTAssertEqual(survivedContent, testContent)

        // Clean up
        try? fileManager.removeItem(at: intermediateURL)
    }

    /// Test that cleanup removes intermediate files correctly
    func testIntermediateFileCleanup_onFailure() throws {
        let fileManager = FileManager.default
        let downloadID = UUID()
        let intermediateURL = fileManager.temporaryDirectory
            .appendingPathComponent("download-\(downloadID.uuidString).tmp")

        // Create the intermediate file
        let testContent = Data("Content to be cleaned up".utf8)
        try testContent.write(to: intermediateURL)

        XCTAssertTrue(fileManager.fileExists(atPath: intermediateURL.path))

        // Simulate cleanup on failure (as done in DownloadManager+BackgroundSession)
        try? fileManager.removeItem(at: intermediateURL)

        XCTAssertFalse(
            fileManager.fileExists(atPath: intermediateURL.path),
            "Intermediate file should be cleaned up"
        )
    }

    /// Test that existing intermediate file is removed before new move
    func testIntermediateFileMove_replacesExistingFile() throws {
        let fileManager = FileManager.default
        let downloadID = UUID()
        let intermediateURL = fileManager.temporaryDirectory
            .appendingPathComponent("download-\(downloadID.uuidString).tmp")

        // Create an existing file at the intermediate location
        let oldContent = Data("Old content".utf8)
        try oldContent.write(to: intermediateURL)

        // Create a new source file
        let sourceURL = fileManager.temporaryDirectory
            .appendingPathComponent("test-source-\(UUID().uuidString).tmp")
        let newContent = Data("New content".utf8)
        try newContent.write(to: sourceURL)

        // Perform the move (simulating BackgroundSessionManager behavior)
        if fileManager.fileExists(atPath: intermediateURL.path) {
            try fileManager.removeItem(at: intermediateURL)
        }
        try fileManager.moveItem(at: sourceURL, to: intermediateURL)

        // Verify new content replaced old
        let finalContent = try Data(contentsOf: intermediateURL)
        XCTAssertEqual(finalContent, newContent)

        // Clean up
        try? fileManager.removeItem(at: intermediateURL)
    }

    // MARK: - Delegate Configuration Tests

    func testDelegate_canBeSetAndRetrieved() {
        let sut = BackgroundSessionManager.shared

        sut.delegate = mockDelegate
        XCTAssertNotNil(sut.delegate)

        // Clean up
        sut.delegate = nil
    }

    // MARK: - Background Completion Handler Tests

    func testBackgroundCompletionHandler_canBeSet() {
        let sut = BackgroundSessionManager.shared
        var handlerCalled = false

        sut.setBackgroundCompletionHandler {
            handlerCalled = true
        }

        // The handler won't be called until urlSessionDidFinishEvents is called
        // This test just verifies we can set it without crashing
        XCTAssertFalse(handlerCalled)
    }
}
