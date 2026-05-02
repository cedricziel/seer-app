import Foundation

/// Public information advertised by a Jellyfin server at
/// `/System/Info/Public`.
public struct ServerInfo: Sendable, Equatable {
    public let serverID: String
    public let productName: String
    public let serverName: String?
    public let localAddress: URL?
    public let version: String?

    public init(
        serverID: String,
        productName: String,
        serverName: String?,
        localAddress: URL?,
        version: String?
    ) {
        self.serverID = serverID
        self.productName = productName
        self.serverName = serverName
        self.localAddress = localAddress
        self.version = version
    }
}

/// Low-level transport for the public-info endpoint. Production uses
/// `URLSession`; tests substitute a scripted stub returning canned bytes.
public protocol ServerInfoTransport: Sendable {
    func fetchPublicInfo(from baseURL: URL) async throws -> Data
}

public struct URLSessionServerInfoTransport: ServerInfoTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchPublicInfo(from baseURL: URL) async throws -> Data {
        let endpoint = baseURL.appendingPathComponent("System/Info/Public")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServerInfoFetcher.ServerInfoError.networkFailure("No HTTP response")
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw ServerInfoFetcher.ServerInfoError.networkFailure("HTTP \(http.statusCode)")
        }
        return data
    }
}

/// Fetches and validates the `/System/Info/Public` payload, used during
/// onboarding to confirm a URL points at a Jellyfin server and to learn
/// the server's `LocalAddress` (its LAN URL when entering via WAN).
public final class ServerInfoFetcher: Sendable {
    public enum ServerInfoError: LocalizedError, Equatable, Sendable {
        case notJellyfin
        case networkFailure(String)
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .notJellyfin:
                "The URL does not appear to be a Jellyfin server."
            case let .networkFailure(message):
                "Network error: \(message)"
            case .invalidResponse:
                "Server returned an unexpected response."
            }
        }
    }

    private let transport: any ServerInfoTransport

    public init(transport: any ServerInfoTransport = URLSessionServerInfoTransport()) {
        self.transport = transport
    }

    public func fetch(from baseURL: URL) async throws -> ServerInfo {
        let data = try await transport.fetchPublicInfo(from: baseURL)
        let raw: RawServerInfo
        do {
            raw = try JSONDecoder().decode(RawServerInfo.self, from: data)
        } catch {
            throw ServerInfoError.notJellyfin
        }
        guard let identifier = raw.id, !identifier.isEmpty else {
            throw ServerInfoError.notJellyfin
        }
        let productName = raw.productName ?? ""
        guard productName.lowercased().contains("jellyfin") else {
            throw ServerInfoError.notJellyfin
        }
        return ServerInfo(
            serverID: identifier,
            productName: productName,
            serverName: raw.serverName,
            localAddress: raw.localAddress.flatMap(URL.init(string:)),
            version: raw.version
        )
    }

    private struct RawServerInfo: Decodable {
        let id: String?
        let productName: String?
        let serverName: String?
        let localAddress: String?
        let version: String?

        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case productName = "ProductName"
            case serverName = "ServerName"
            case localAddress = "LocalAddress"
            case version = "Version"
        }
    }
}
