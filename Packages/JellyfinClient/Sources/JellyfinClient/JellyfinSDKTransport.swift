import Foundation
import Get
import JellyfinAPI

/// Executes generated Jellyfin requests while leaving response decoding and HTTP error mapping to app clients.
public struct JellyfinSDKTransport: Sendable {
    private let client: JellyfinAPI.JellyfinClient

    public init(
        serverURL: URL,
        accessToken: String? = nil,
        deviceID: String,
        clientName: String = "Seer",
        clientVersion: String = "1.0.0",
        sessionConfiguration: URLSessionConfiguration = .default,
        sessionDelegate: URLSessionDelegate? = nil
    ) {
        let delegate = SDKRequestDelegate()
        let client = JellyfinAPI.JellyfinClient(
            configuration: .init(
                url: serverURL,
                accessToken: accessToken,
                client: clientName,
                deviceName: "iOS",
                deviceID: deviceID,
                version: clientVersion
            ),
            delegate: delegate,
            sessionConfiguration: sessionConfiguration,
            sessionDelegate: sessionDelegate
        )
        delegate.jellyfinClient = client
        self.client = client
    }

    func url(for request: Request<some Any>) -> URL? {
        encodedSDKURL(for: request, client: client)
    }

    func data(for request: Request<some Any>) async throws -> (Data, HTTPURLResponse) {
        let response = try await client.data(for: request)
        guard let httpResponse = response.response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (response.value, httpResponse)
    }

    /// Sends the app's playback negotiation payload through the generated endpoint.
    public func playbackInfo(
        itemID: String,
        body: some Encodable & Sendable
    ) async throws -> (Data, HTTPURLResponse) {
        try await data(for: Paths.getPostedPlaybackInfo(itemID: itemID), body: body)
    }

    /// Sends a started-session payload through the generated playback endpoint.
    public func playbackStarted(body: some Encodable & Sendable) async throws -> (Data, HTTPURLResponse) {
        try await data(for: Paths.reportPlaybackStart(), body: body)
    }

    /// Sends a progress payload through the generated playback endpoint.
    public func playbackProgress(body: some Encodable & Sendable) async throws -> (Data, HTTPURLResponse) {
        try await data(for: Paths.reportPlaybackProgress(), body: body)
    }

    /// Sends a stopped-session payload through the generated playback endpoint.
    public func playbackStopped(body: some Encodable & Sendable) async throws -> (Data, HTTPURLResponse) {
        try await data(for: Paths.reportPlaybackStopped(), body: body)
    }

    private func data(
        for request: Request<some Any>,
        body: some Encodable & Sendable
    ) async throws -> (Data, HTTPURLResponse) {
        var request = request
        // SDK DTO defaults materialize omitted flags and can change playback negotiation.
        request.body = body
        return try await data(for: request)
    }
}

private final class SDKRequestDelegate: APIClientDelegate, @unchecked Sendable {
    weak var jellyfinClient: JellyfinAPI.JellyfinClient?

    func client(_: APIClient, makeURLForRequest request: Request<some Any>) throws -> URL? {
        jellyfinClient.flatMap { encodedSDKURL(for: request, client: $0) }
    }

    func client(_: APIClient, validateResponse _: HTTPURLResponse, data _: Data, task _: URLSessionTask) throws {
        // App clients distinguish authentication failures and retain server error bodies.
    }
}

private func encodedSDKURL(
    for request: Request<some Any>,
    client: JellyfinAPI.JellyfinClient
) -> URL? {
    guard let url = client.url(with: request) else { return nil }
    var generatedQuery = URLComponents()
    generatedQuery.queryItems = request.query?.map { URLQueryItem(name: $0.0, value: $0.1) }
    guard let encodedQuery = generatedQuery.percentEncodedQuery, !encodedQuery.isEmpty,
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
    let baseQuery = URLComponents(url: client.configuration.url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
    // ASP.NET treats '+' as space; escape generated values without rewriting the base query.
    components.percentEncodedQuery = [baseQuery, encodedQuery.replacingOccurrences(of: "+", with: "%2B")]
        .compactMap(\.self).filter { !$0.isEmpty }.joined(separator: "&")
    return components.url
}
