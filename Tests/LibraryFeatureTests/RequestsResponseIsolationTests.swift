import JellyseerrClient
@testable import SeerApp
import SeerCore
import XCTest

@MainActor
final class RequestsResponseIsolationTests: XCTestCase {
    func testPreviousServerSuccessCannotReplaceNewServersRows() async {
        let api = DelayedRequestService()
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let old = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        identity.id = UUID()
        let current = Task { await model.loadRequests() }
        await api.waitForCalls(2)
        api.succeed(1, ids: [2])
        await current.value
        api.succeed(0, ids: [1])
        await old.value
        XCTAssertEqual(model.requests.map(\.id), [2])
    }

    func testObsoleteFailureCannotClearCurrentLoadingOrPublishError() async {
        let api = DelayedRequestService()
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let old = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        model.selectedFilter = .pending
        let current = Task { await model.filterChanged() }
        await api.waitForCalls(2)
        api.fail(0)
        await old.value
        XCTAssertTrue(model.isLoading)
        XCTAssertNil(model.errorMessage)
        api.succeed(1, ids: [2])
        await current.value
        XCTAssertEqual(model.requests.map(\.id), [2])
    }

    func testSortChangeRejectsSuccessBeforeReloadCallback() async {
        let api = DelayedRequestService()
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let old = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        model.selectedSort = .modified
        api.succeed(0, ids: [1])
        await old.value
        XCTAssertTrue(model.requests.isEmpty)
        XCTAssertFalse(model.isLoading)
    }

    func testPreviousServerFailureCannotPublishError() async {
        let api = DelayedRequestService()
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let old = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        identity.id = UUID()
        let current = Task { await model.loadRequests() }
        await api.waitForCalls(2)
        api.fail(0)
        await old.value
        XCTAssertTrue(model.isLoading)
        XCTAssertNil(model.errorMessage)
        api.succeed(1, ids: [2])
        await current.value
    }

    func testRefreshSupersedesSuccessfulPagination() async {
        let (model, api) = await loadedModel()
        let page = Task { await model.loadMoreRequests() }
        await api.waitForCalls(2)
        let refresh = Task { await model.refresh() }
        await api.waitForCalls(3)
        api.succeed(2, ids: [3])
        await refresh.value
        api.succeed(1, ids: [2])
        await page.value
        XCTAssertEqual(model.requests.map(\.id), [3])
        XCTAssertFalse(model.isLoadingMore)
    }

    func testObsoletePaginationFailureCannotClearNewPageLoadingOrRewindOffset() async {
        let (model, api) = await loadedModel()
        let oldPage = Task { await model.loadMoreRequests() }
        await api.waitForCalls(2)
        let refresh = Task { await model.refresh() }
        await api.waitForCalls(3)
        api.succeed(2, ids: [3])
        await refresh.value
        let newPage = Task { await model.loadMoreRequests() }
        await api.waitForCalls(4)
        api.fail(1)
        await oldPage.value
        XCTAssertTrue(model.isLoadingMore)
        api.succeed(3, ids: [4])
        await newPage.value
        let nextPage = Task { await model.loadMoreRequests() }
        await api.waitForCalls(5)
        XCTAssertEqual(api.skips, [0, 20, 0, 20, 40])
        api.succeed(4, ids: [5])
        await nextPage.value
        XCTAssertEqual(model.requests.map(\.id), [3, 4, 5])
    }

    func testManualRefreshSupersedesSilentRefresh() async {
        let (model, api) = await loadedModel()
        let silent = Task { await model.silentRefresh() }
        await api.waitForCalls(2)
        let refresh = Task { await model.refresh() }
        await api.waitForCalls(3)
        api.succeed(2, ids: [3])
        await refresh.value
        api.succeed(1, ids: [2])
        await silent.value
        XCTAssertEqual(model.requests.map(\.id), [3])
    }

    func testPaginationSupersedesSilentRefresh() async {
        let (model, api) = await loadedModel()
        let silent = Task { await model.silentRefresh() }
        await api.waitForCalls(2)
        let page = Task { await model.loadMoreRequests() }
        await api.waitForCalls(3)
        api.succeed(2, ids: [3])
        await page.value
        api.succeed(1, ids: [2])
        await silent.value
        XCTAssertEqual(model.requests.map(\.id), [1, 3])
    }

    func testFilterChangeRejectsPaginationSuccess() async {
        let (model, api) = await loadedModel()
        let page = Task { await model.loadMoreRequests() }
        await api.waitForCalls(2)
        model.selectedFilter = .pending
        let refresh = Task { await model.filterChanged() }
        await api.waitForCalls(3)
        api.succeed(2, ids: [3])
        await refresh.value
        api.succeed(1, ids: [2])
        await page.value
        XCTAssertEqual(model.requests.map(\.id), [3])
    }

    func testSilentFailureDoesNotOverwriteSuccessfulManualRefresh() async {
        let (model, api) = await loadedModel()
        let silent = Task { await model.silentRefresh() }
        await api.waitForCalls(2)
        let refresh = Task { await model.refresh() }
        await api.waitForCalls(3)
        api.succeed(2, ids: [3])
        await refresh.value
        api.fail(1)
        await silent.value
        XCTAssertEqual(model.requests.map(\.id), [3])
        XCTAssertNil(model.errorMessage)
    }

    func testOldSheetCannotMutateIdenticalRequestFromNewServer() async throws {
        let api = DelayedRequestService()
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let first = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        api.succeed(0, ids: [1])
        await first.value
        let request = try XCTUnwrap(model.requests.first)
        let oldIdentity = model.requestIdentity
        identity.id = UUID()
        let second = Task { await model.loadRequests() }
        await api.waitForCalls(2)
        api.succeed(1, ids: [1])
        await second.value
        try await model.cancelRequest(request, identity: oldIdentity)
        try await model.approveRequest(request, identity: oldIdentity)
        try await model.declineRequest(request, identity: oldIdentity)
        XCTAssertTrue(api.actions.isEmpty)
    }

    func testServerChangeRejectsActionsBeforeReloadCallback() async throws {
        let api = DelayedRequestService()
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let first = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        api.succeed(0, ids: [1])
        await first.value
        let request = try XCTUnwrap(model.requests.first)
        let oldIdentity = model.requestIdentity
        identity.id = UUID()
        try await model.cancelRequest(request, identity: oldIdentity)
        try await model.approveRequest(request, identity: oldIdentity)
        try await model.declineRequest(request, identity: oldIdentity)
        XCTAssertTrue(api.actions.isEmpty)
    }

    func testCancelledLoadDoesNotPublishRowsOrLeaveLoading() async {
        let api = DelayedRequestService()
        let serverID = UUID()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { serverID })
        let task = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        task.cancel()
        api.succeed(0, ids: [1])
        await task.value
        XCTAssertTrue(model.requests.isEmpty)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    func testCurrentPaginationFailureRetriesSameOffset() async {
        let (model, api) = await loadedModel()
        let failed = Task { await model.loadMoreRequests() }
        await api.waitForCalls(2)
        api.fail(1)
        await failed.value
        let retry = Task { await model.loadMoreRequests() }
        await api.waitForCalls(3)
        XCTAssertEqual(api.skips, [0, 20, 20])
        api.succeed(2, ids: [2])
        await retry.value
        XCTAssertEqual(model.requests.map(\.id), [1, 2])
        XCTAssertFalse(model.isLoadingMore)
    }

    func testPaginationDoesNotStartDuringManualRefresh() async {
        let (model, api) = await loadedModel()
        let refresh = Task { await model.refresh() }
        await api.waitForCalls(2)
        await model.loadMoreRequests()
        XCTAssertEqual(api.skips, [0, 0])
        api.succeed(1, ids: [2])
        await refresh.value
    }

    func testOldActionSuccessDoesNotRefreshNewServer() async throws {
        let api = DelayedRequestService()
        api.holdActions = true
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let first = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        api.succeed(0, ids: [1])
        await first.value
        let request = try XCTUnwrap(model.requests.first)
        let token = model.requestIdentity
        let action = Task { try await model.cancelRequest(request, identity: token) }
        await api.waitForAction()
        identity.id = UUID()
        let second = Task { await model.loadRequests() }
        await api.waitForCalls(2)
        api.succeed(1, ids: [1])
        await second.value
        api.finishAction()
        try await action.value
        XCTAssertEqual(api.actions, [1])
        XCTAssertEqual(api.skips, [0, 0])
    }

    func testOldActionFailureDoesNotEscapeIntoNewServer() async throws {
        let api = DelayedRequestService()
        api.holdActions = true
        let identity = ServerIdentity()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { identity.id })
        let first = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        api.succeed(0, ids: [1])
        await first.value
        let request = try XCTUnwrap(model.requests.first)
        let token = model.requestIdentity
        let action = Task { try await model.cancelRequest(request, identity: token) }
        await api.waitForAction()
        identity.id = UUID()
        let second = Task { await model.loadRequests() }
        await api.waitForCalls(2)
        api.succeed(1, ids: [1])
        await second.value
        api.finishAction(error: URLError(.timedOut))
        try await action.value
        XCTAssertEqual(api.skips, [0, 0])
        XCTAssertNil(model.errorMessage)
    }

    private func loadedModel() async -> (RequestsViewModel, DelayedRequestService) {
        let api = DelayedRequestService()
        let serverID = UUID()
        let model = RequestsViewModel(appState: AppState(), service: api, serverIdentity: { serverID })
        let task = Task { await model.loadRequests() }
        await api.waitForCalls(1)
        api.succeed(0, ids: [1])
        await task.value
        return (model, api)
    }
}

@MainActor
private final class ServerIdentity {
    var id = UUID()
}

@MainActor
private final class DelayedRequestService: RequestService {
    var skips: [Int] = []
    var actions: [Int] = []
    var holdActions = false
    private var actionWaiter: CheckedContinuation<Void, Never>?
    private var pendingAction: CheckedContinuation<Void, Error>?

    func waitForAction() async {
        if !actions.isEmpty { return }
        await withCheckedContinuation { actionWaiter = $0 }
    }

    func finishAction(error: Error? = nil) {
        if let error {
            pendingAction?.resume(throwing: error)
        } else {
            pendingAction?.resume()
        }
        pendingAction = nil
    }

    private var calls: [CheckedContinuation<RequestsResponse, Error>] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func waitForCalls(_ count: Int) async {
        if calls.count >= count {
            return
        }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func getRequests(
        take _: Int,
        skip: Int,
        filter _: JellyseerrService.RequestFilter,
        sort _: JellyseerrService.RequestSort
    ) async throws -> RequestsResponse {
        skips.append(skip)
        return try await withCheckedThrowingContinuation { continuation in
            calls.append(continuation)
            let ready = waiters.filter { calls.count >= $0.0 }
            waiters.removeAll { calls.count >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
    }

    func succeed(_ call: Int, ids: [Int], total: Int = 40) {
        let requests: [[String: Any]] = ids.map {
            [
                "id": $0,
                "status": 1,
                "createdAt": "2026-01-01",
                "updatedAt": "2026-01-01",
                "type": "movie",
                "is4k": false,
                "media": ["id": $0],
                "requestedBy": ["id": 1]
            ]
        }
        let json: [String: Any] = [
            "pageInfo": ["pages": 2, "pageSize": 20, "results": total, "page": 1], "results": requests
        ]
        do {
            let response = try JSONDecoder().decode(
                RequestsResponse.self, from: JSONSerialization.data(withJSONObject: json)
            )
            calls[call].resume(returning: response)
        } catch {
            XCTFail("Invalid response fixture: \(error)")
            calls[call].resume(throwing: error)
        }
    }

    func fail(_ call: Int) {
        calls[call].resume(throwing: URLError(.timedOut))
    }

    func cancelRequest(id: Int) async throws {
        actions.append(id)
        if holdActions {
            try await withCheckedThrowingContinuation { continuation in
                pendingAction = continuation
                actionWaiter?.resume()
                actionWaiter = nil
            }
        } else {
            throw URLError(.unsupportedURL)
        }
    }

    func approveRequest(id: Int) async throws -> MediaRequest {
        actions.append(id)
        throw URLError(.unsupportedURL)
    }

    func declineRequest(id: Int) async throws -> MediaRequest {
        actions.append(id)
        throw URLError(.unsupportedURL)
    }

    func getMovieDetails(tmdbId _: Int) async throws -> MovieDetails {
        throw URLError(.unsupportedURL)
    }

    func getTVDetails(tmdbId _: Int) async throws -> TVDetails {
        throw URLError(.unsupportedURL)
    }
}
