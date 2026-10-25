import Foundation

public actor JellyseerrService {
    public enum RequestFilter: String, Sendable { case all, pending, approved, declined, available, processing }
    public enum RequestSort: String, Sendable { case added, modified }
    public init(serverURL _: URL, apiKey _: String) {
        fatalError("Verification must inject its API")
    }

    public func getRequests(
        take _: Int,
        skip _: Int,
        filter _: RequestFilter,
        sort _: RequestSort
    ) async throws -> RequestsResponse {
        fatalError("Verification must inject its API")
    }

    public func cancelRequest(id _: Int) async throws {
        fatalError("Verification must inject its API")
    }

    public func approveRequest(id _: Int) async throws -> MediaRequest {
        fatalError("Verification must inject its API")
    }

    public func declineRequest(id _: Int) async throws -> MediaRequest {
        fatalError("Verification must inject its API")
    }

    public func getMovieDetails(tmdbId _: Int) async throws
        -> MovieDetails {
        fatalError("Verification must inject its API")
    }

    public func getTVDetails(tmdbId _: Int) async throws -> TVDetails {
        fatalError("Verification must inject its API")
    }
}
