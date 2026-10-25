import JellyseerrClient
@testable import SeerApp
import SeerCore
import SwiftData
import XCTest

@MainActor
final class RequestCacheTests: XCTestCase {
    func testPartialPagePreservesPreviouslyCachedRequests() throws {
        let context = try makeContext()
        let serverID = UUID()
        context.insert(cachedRequest(id: 2, serverID: serverID))

        try RequestsViewModel.cacheRequests(
            response(ids: [1], total: 2), filter: .all, serverID: serverID, context: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<CachedRequest>()).map(\.requestID).sorted(), [1, 2])
    }

    func testCompleteFilteredPagePreservesRequestsOutsideFilter() throws {
        let context = try makeContext()
        let serverID = UUID()
        context.insert(cachedRequest(id: 2, serverID: serverID))

        try RequestsViewModel.cacheRequests(
            response(ids: [1], total: 1), filter: .pending, serverID: serverID, context: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<CachedRequest>()).map(\.requestID).sorted(), [1, 2])
    }

    func testCompleteUnfilteredSnapshotPrunesOnlyItsServersMissingRequests() throws {
        let context = try makeContext()
        let serverID = UUID()
        let otherServerID = UUID()
        context.insert(cachedRequest(id: 2, serverID: serverID))
        context.insert(cachedRequest(id: 3, serverID: otherServerID))

        try RequestsViewModel.cacheRequests(
            response(ids: [1], total: 1), filter: .all, serverID: serverID, context: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<CachedRequest>()).map(\.requestID).sorted(), [1, 3])
    }

    func testEmptyCompleteUnfilteredSnapshotRemovesDeletedRequests() throws {
        let context = try makeContext()
        let serverID = UUID()
        context.insert(cachedRequest(id: 2, serverID: serverID))

        try RequestsViewModel.cacheRequests(
            response(ids: [], total: 0), filter: .all, serverID: serverID, context: context
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CachedRequest>()), 0)
    }

    func testLaterPageUpsertsWithoutPruningEarlierCachedRequests() throws {
        let context = try makeContext()
        let serverID = UUID()
        context.insert(cachedRequest(id: 1, serverID: serverID))

        try RequestsViewModel.cacheRequests(
            response(ids: [2], total: 1, page: 2), filter: .all, serverID: serverID, context: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<CachedRequest>()).map(\.requestID).sorted(), [1, 2])
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CachedRequest.self, configurations: configuration)
        return ModelContext(container)
    }

    private func cachedRequest(id: Int, serverID: UUID) -> CachedRequest {
        CachedRequest(
            serverConfigurationID: serverID, requestID: id, title: "Cached", mediaType: "movie",
            statusRawValue: 1, requestedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func response(ids: [Int], total: Int, page: Int = 1) throws -> RequestsResponse {
        let requests: [[String: Any]] = ids.map { id -> [String: Any] in
            [
                "id": id, "status": 1, "createdAt": "2026-01-01T00:00:00Z",
                "updatedAt": "2026-01-01T00:00:00Z", "type": "movie", "is4k": false,
                "media": ["id": id, "title": "Movie \(id)"], "requestedBy": ["id": 1]
            ]
        }
        let json: [String: Any] = [
            "pageInfo": ["pages": 1, "pageSize": 20, "results": total, "page": page],
            "results": requests
        ]
        return try JSONDecoder().decode(RequestsResponse.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
