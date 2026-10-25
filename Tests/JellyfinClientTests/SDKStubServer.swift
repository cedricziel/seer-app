import Foundation
import JellyfinClient

final class SDKStubServer: @unchecked Sendable {
    let url: URL
    private let lock = NSLock()
    private var recordedRequests: [URLRequest] = []
    private var recordedBodies: [Data] = []
    private var responses: [(Int, Data)]

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    var bodies: [Data] {
        lock.withLock { recordedBodies }
    }

    var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SDKStubProtocol.self]
        return configuration
    }

    init(status: Int, body: String, baseQuery: String? = nil) {
        let base = URL(string: "https://sdk-\(UUID().uuidString.lowercased()).invalid/jellyfin")!
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = baseQuery
        url = components.url!
        responses = [(status, Data(body.utf8))]
        SDKStubProtocol.register(self)
    }

    deinit { SDKStubProtocol.unregister(url.host!) }

    func enqueue(status: Int, body: String) {
        lock.withLock { responses.append((status, Data(body.utf8))) }
    }

    func transport(token: String? = nil) -> JellyfinSDKTransport {
        JellyfinSDKTransport(
            serverURL: url,
            accessToken: token,
            deviceID: "device-1",
            sessionConfiguration: configuration
        )
    }

    func service(token: String? = "TOKEN-1", userID: String? = "user-1") -> JellyfinService {
        JellyfinService(
            serverURL: url,
            accessToken: token,
            userID: userID,
            deviceID: "device-1",
            sessionConfiguration: configuration
        )
    }

    func respond(to request: URLRequest) -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readBody) ?? Data()
        let (status, responseBody) = lock.withLock {
            recordedRequests.append(request)
            recordedBodies.append(body)
            return responses.count > 1 ? responses.removeFirst() : responses[0]
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (response, responseBody)
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { return data }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
}

private final class SDKStubProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var servers: [String: WeakSDKStubServer] = [:]

    static func register(_ server: SDKStubServer) {
        lock.withLock { servers[server.url.host!] = WeakSDKStubServer(server) }
    }

    static func unregister(_ host: String) {
        _ = lock.withLock { servers.removeValue(forKey: host) }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasPrefix("sdk-") == true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host,
              let server = Self.lock.withLock({ Self.servers[host]?.value }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let (response, data) = server.respond(to: request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class WeakSDKStubServer: @unchecked Sendable {
    weak var value: SDKStubServer?
    init(_ value: SDKStubServer) {
        self.value = value
    }
}
