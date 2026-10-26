@testable import DownloadClient
import Foundation
import XCTest

final class DownloadTransferTests: XCTestCase {
    private var directory: URL!
    private var session: TransferSession!
    private var manager: BackgroundSessionManager!
    private var delegate: MockBackgroundSessionDelegate!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        session = TransferSession()
        manager = BackgroundSessionManager(session: session, pendingDirectory: directory)
        delegate = MockBackgroundSessionDelegate()
        manager.delegate = delegate
    }

    override func tearDownWithError() throws {
        session.invalidateAndCancel()
        try FileManager.default.removeItem(at: directory)
        manager = nil
        delegate = nil
        session = nil
    }

    func testNewDownloadDisallowsCellularByDefault() throws {
        _ = try manager.startDownload(url: XCTUnwrap(URL(string: "https://media.invalid/video")), downloadID: UUID())

        XCTAssertFalse(try XCTUnwrap(session.request).allowsCellularAccess)
        XCTAssertTrue(session.task.didResume)
    }

    func testDownloadCanWaitForDurableTaskRegistrationBeforeStarting() throws {
        let task = try manager.startDownload(
            url: XCTUnwrap(URL(string: "https://media.invalid/video")), downloadID: UUID(), startImmediately: false
        )

        XCTAssertFalse(session.task.didResume)
        task.resume()
        XCTAssertTrue(session.task.didResume)
    }

    func testNewDownloadAllowsCellularWhenWiFiOnlyIsDisabled() throws {
        _ = try manager.startDownload(
            url: XCTUnwrap(URL(string: "https://media.invalid/video")), downloadID: UUID(), wifiOnly: false
        )

        XCTAssertTrue(try XCTUnwrap(session.request).allowsCellularAccess)
    }

    func testResumeKeepsWiFiOnlyRequestRestricted() throws {
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://media.invalid/video")))
        request.allowsCellularAccess = false
        session.task.request = request

        let task = manager.resumeDownload(resumeData: Data(), downloadID: UUID())

        XCTAssertNotNil(task)
        XCTAssertTrue(session.task.didResume)
        XCTAssertFalse(try XCTUnwrap(task?.originalRequest).allowsCellularAccess)
    }

    func testResumedDownloadCanWaitForDurableTaskRegistrationBeforeStarting() throws {
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://media.invalid/video")))
        request.allowsCellularAccess = false
        session.task.request = request

        let task = manager.resumeDownload(resumeData: Data(), downloadID: UUID(), startImmediately: false)

        XCTAssertNotNil(task)
        XCTAssertFalse(session.task.didResume)
        task?.resume()
        XCTAssertTrue(session.task.didResume)
    }

    func testResumeRejectsCellularRequestWhenWiFiOnlyIsEnabled() throws {
        session.task.request = try URLRequest(url: XCTUnwrap(URL(string: "https://media.invalid/video")))

        let task = manager.resumeDownload(resumeData: Data(), downloadID: UUID())

        XCTAssertNil(task)
        XCTAssertFalse(session.task.didResume)
        XCTAssertTrue(session.task.didCancel)
        XCTAssertNil(manager.downloadID(forTask: session.task.taskIdentifier))
    }

    func testResumeRejectsRestrictedRequestWhenCellularIsEnabled() throws {
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://media.invalid/video")))
        request.allowsCellularAccess = false
        session.task.request = request

        let task = manager.resumeDownload(resumeData: Data(), downloadID: UUID(), wifiOnly: false)

        XCTAssertNil(task)
        XCTAssertFalse(session.task.didResume)
        XCTAssertTrue(session.task.didCancel)
    }

    func testResumeAllowsCellularWhenPolicyIsUnchanged() throws {
        session.task.request = try URLRequest(url: XCTUnwrap(URL(string: "https://media.invalid/video")))

        let task = manager.resumeDownload(resumeData: Data(), downloadID: UUID(), wifiOnly: false)

        XCTAssertNotNil(task)
        XCTAssertTrue(session.task.didResume)
    }

    func testResumeWithoutOriginalRequestRestartsRatherThanBypassingPolicy() {
        let task = manager.resumeDownload(resumeData: Data(), downloadID: UUID())

        XCTAssertNil(task)
        XCTAssertFalse(session.task.didResume)
        XCTAssertTrue(session.task.didCancel)
    }

    func testRecoveredUnrestrictedTaskDoesNotMatchWiFiOnlyPolicy() async throws {
        session.task.request = try URLRequest(url: XCTUnwrap(URL(string: "https://media.invalid/video")))

        let matches = await manager.matchesNetworkPolicy(taskIdentifier: session.task.taskIdentifier, wifiOnly: true)

        XCTAssertFalse(matches)
    }

    func testRecoveredRestrictedTaskMatchesWiFiOnlyPolicy() async throws {
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://media.invalid/video")))
        request.allowsCellularAccess = false
        session.task.request = request

        let matches = await manager.matchesNetworkPolicy(taskIdentifier: session.task.taskIdentifier, wifiOnly: true)

        XCTAssertTrue(matches)
    }

    func testUnauthorizedResponseFailsWithoutPreservingFile() throws {
        try assertRejectedResponse(status: 401)
    }

    func testMissingMediaResponseFailsWithoutPreservingFile() throws {
        try assertRejectedResponse(status: 404)
    }

    func testServerErrorResponseFailsWithoutPreservingFile() throws {
        try assertRejectedResponse(status: 500)
    }

    func testSuccessfulResponsePreservesMediaBeforeCompletion() throws {
        try assertSuccessfulResponse(status: 200)
    }

    func testPartialContentResponsePreservesResumedMediaBeforeCompletion() throws {
        try assertSuccessfulResponse(status: 206)
    }

    private func assertSuccessfulResponse(status: Int) throws {
        let source = directory.appendingPathComponent("source.tmp")
        let content = Data("video bytes".utf8)
        try content.write(to: source)
        session.task.httpResponse = try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://media.invalid/video")), statusCode: status,
            httpVersion: nil, headerFields: nil
        )
        manager.registerTask(session.task.taskIdentifier, forDownload: UUID())

        manager.urlSession(session, downloadTask: session.task, didFinishDownloadingTo: source)

        XCTAssertTrue(delegate.failEvents.isEmpty)
        let event = try XCTUnwrap(delegate.completeEvents.first)
        XCTAssertEqual(try Data(contentsOf: event.tempFileURL), content)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertNil(manager.downloadID(forTask: session.task.taskIdentifier))
    }

    func testNonHTTPResponseFailsWithoutPreservingFile() throws {
        let source = directory.appendingPathComponent("source.tmp")
        try Data("invalid response".utf8).write(to: source)
        session.task.httpResponse = try URLResponse(
            url: XCTUnwrap(URL(string: "https://media.invalid/video")), mimeType: nil,
            expectedContentLength: 0, textEncodingName: nil
        )

        manager.urlSession(session, downloadTask: session.task, didFinishDownloadingTo: source)

        XCTAssertTrue(delegate.completeEvents.isEmpty)
        XCTAssertEqual(delegate.failEvents.count, 1)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    private func assertRejectedResponse(status: Int) throws {
        let source = directory.appendingPathComponent("error.tmp")
        try Data("server error".utf8).write(to: source)
        session.task.httpResponse = HTTPURLResponse(
            url: URL(string: "https://media.invalid/video")!, statusCode: status,
            httpVersion: nil, headerFields: nil
        )
        manager.registerTask(session.task.taskIdentifier, forDownload: UUID())

        manager.urlSession(session, downloadTask: session.task, didFinishDownloadingTo: source)

        XCTAssertTrue(delegate.completeEvents.isEmpty)
        XCTAssertEqual(delegate.failEvents.count, 1)
        XCTAssertNil(delegate.failEvents.first?.resumeData)
        XCTAssertNil(manager.downloadID(forTask: session.task.taskIdentifier))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}

private final class TransferSession: URLSession, @unchecked Sendable {
    let task = TransferTask()
    var request: URLRequest?

    override func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
        self.request = request
        task.request = request
        return task
    }

    override func downloadTask(withResumeData _: Data) -> URLSessionDownloadTask {
        task
    }

    override func getAllTasks(completionHandler: @escaping @Sendable ([URLSessionTask]) -> Void) {
        completionHandler([task])
    }

    override func invalidateAndCancel() {}
}

private final class TransferTask: URLSessionDownloadTask, @unchecked Sendable {
    var request: URLRequest?
    var httpResponse: URLResponse?
    var didResume = false
    var didCancel = false

    override var taskIdentifier: Int {
        41
    }

    override var originalRequest: URLRequest? {
        request
    }

    override var response: URLResponse? {
        httpResponse
    }

    override func resume() {
        didResume = true
    }

    override func cancel() {
        didCancel = true
    }
}
