import Foundation

// MARK: - Transport abstraction

public struct QuickConnectInitiateResponse: Sendable, Equatable {
    public let code: String
    public let secret: String

    public init(code: String, secret: String) {
        self.code = code
        self.secret = secret
    }
}

public struct QuickConnectStateResponse: Sendable, Equatable {
    public let authenticated: Bool

    public init(authenticated: Bool) {
        self.authenticated = authenticated
    }
}

/// Low-level transport for the Quick Connect endpoints. Production uses
/// `URLSession`; tests substitute a scripted stub.
public protocol QuickConnectTransport: Sendable {
    func isEnabled(serverURL: URL) async throws -> Bool
    func initiate(serverURL: URL) async throws -> QuickConnectInitiateResponse
    func pollState(serverURL: URL, secret: String) async throws -> QuickConnectStateResponse
    func authenticate(serverURL: URL, secret: String) async throws -> AuthResponse
}

// MARK: - Clock abstraction

public protocol QuickConnectClock: Sendable {
    func now() -> ContinuousClock.Instant
    func sleep(for duration: Duration) async throws
}

public struct SystemQuickConnectClock: QuickConnectClock {
    public init() {}
    public func now() -> ContinuousClock.Instant {
        .now
    }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

// MARK: - Session

@MainActor
public final class QuickConnectSession: ObservableObject {
    public enum QuickConnectError: LocalizedError, Equatable, Sendable {
        case notEnabled
        case networkFailure(String)
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .notEnabled:
                "Quick Connect is not enabled on this server."
            case let .networkFailure(message):
                "Network error: \(message)"
            case .invalidResponse:
                "Server returned an unexpected response."
            }
        }
    }

    public enum State: Sendable, Equatable {
        case idle
        case pending(code: String, secret: String)
        case approved(AuthResponse)
        case expired
        case failed(QuickConnectError)
        case cancelled

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.expired, .expired), (.cancelled, .cancelled):
                true
            case let (.pending(lhsCode, lhsSecret), .pending(rhsCode, rhsSecret)):
                lhsCode == rhsCode && lhsSecret == rhsSecret
            case let (.approved(lhsAuth), .approved(rhsAuth)):
                lhsAuth.accessToken == rhsAuth.accessToken && lhsAuth.user.id == rhsAuth.user.id
            case let (.failed(lhsError), .failed(rhsError)):
                lhsError == rhsError
            default:
                false
            }
        }
    }

    @Published public private(set) var state: State = .idle

    private let serverURL: URL
    private let transport: any QuickConnectTransport
    private let clock: any QuickConnectClock
    private let timeout: Duration
    private var pollingTask: Task<Void, Never>?
    private var startedAt: ContinuousClock.Instant?

    public init(
        serverURL: URL,
        transport: any QuickConnectTransport,
        clock: any QuickConnectClock = SystemQuickConnectClock(),
        timeout: Duration = .seconds(600)
    ) {
        self.serverURL = serverURL
        self.transport = transport
        self.clock = clock
        self.timeout = timeout
    }

    /// Begin a Quick Connect session. Sets `state` and starts polling on success.
    public func start() async {
        do {
            let enabled = try await transport.isEnabled(serverURL: serverURL)
            guard enabled else {
                state = .failed(.notEnabled)
                return
            }
            let initiated = try await transport.initiate(serverURL: serverURL)
            state = .pending(code: initiated.code, secret: initiated.secret)
            startedAt = clock.now()
            startPolling(secret: initiated.secret)
        } catch let qcError as QuickConnectError {
            state = .failed(qcError)
        } catch {
            state = .failed(.networkFailure(error.localizedDescription))
        }
    }

    /// Cancel the session. Stops polling and never exchanges the secret.
    public func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .cancelled
    }

    /// Compute the next poll interval based on elapsed time. Pure for testing.
    static func nextPollInterval(elapsed: Duration) -> Duration {
        elapsed > .seconds(30) ? .seconds(3) : .seconds(1)
    }

    private func startPolling(secret: String) {
        pollingTask = Task { [weak self] in
            await self?.pollLoop(secret: secret)
        }
    }

    private func pollLoop(secret: String) async {
        guard let startedAt else { return }
        while !Task.isCancelled {
            let elapsed = clock.now() - startedAt
            if elapsed > timeout {
                state = .expired
                return
            }
            do {
                let pollResponse = try await transport.pollState(serverURL: serverURL, secret: secret)
                if pollResponse.authenticated {
                    let auth = try await transport.authenticate(serverURL: serverURL, secret: secret)
                    state = .approved(auth)
                    return
                }
            } catch {
                state = .failed(.networkFailure(error.localizedDescription))
                return
            }
            let interval = Self.nextPollInterval(elapsed: elapsed)
            do {
                try await clock.sleep(for: interval)
            } catch {
                return
            }
        }
    }
}

// MARK: - URLSession transport

public struct URLSessionQuickConnectTransport: QuickConnectTransport {
    private let session: URLSession
    private let clientName: String
    private let deviceID: String
    private let clientVersion: String

    public init(
        session: URLSession = .shared,
        clientName: String = "Seer",
        clientVersion: String = "1.0.0",
        deviceID: String
    ) {
        self.session = session
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.deviceID = deviceID
    }

    public func isEnabled(serverURL: URL) async throws -> Bool {
        let url = serverURL.appendingPathComponent("QuickConnect/Enabled")
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            return false
        }
        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return body == "true"
    }

    public func initiate(serverURL: URL) async throws -> QuickConnectInitiateResponse {
        let url = serverURL.appendingPathComponent("QuickConnect/Initiate")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        let raw = try JSONDecoder().decode(InitiateRaw.self, from: data)
        return QuickConnectInitiateResponse(code: raw.code, secret: raw.secret)
    }

    public func pollState(serverURL: URL, secret: String) async throws -> QuickConnectStateResponse {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("QuickConnect/Connect"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "secret", value: secret)]
        guard let url = components?.url else {
            throw QuickConnectSession.QuickConnectError.invalidResponse
        }
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        try Self.validate(response: response, data: data)
        let raw = try JSONDecoder().decode(StateRaw.self, from: data)
        return QuickConnectStateResponse(authenticated: raw.authenticated)
    }

    public func authenticate(serverURL: URL, secret: String) async throws -> AuthResponse {
        let url = serverURL.appendingPathComponent("Users/AuthenticateWithQuickConnect")
        var request = authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["Secret": secret])
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let header = "MediaBrowser Client=\"\(clientName)\", Device=\"iOS\", "
            + "DeviceId=\"\(deviceID)\", Version=\"\(clientVersion)\""
        request.addValue(header, forHTTPHeaderField: "Authorization")
        return request
    }

    private static func validate(response: URLResponse, data _: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw QuickConnectSession.QuickConnectError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw QuickConnectSession.QuickConnectError.networkFailure("HTTP \(http.statusCode)")
        }
    }

    private struct InitiateRaw: Decodable {
        let code: String
        let secret: String
        enum CodingKeys: String, CodingKey {
            case code = "Code"
            case secret = "Secret"
        }
    }

    private struct StateRaw: Decodable {
        let authenticated: Bool
        enum CodingKeys: String, CodingKey {
            case authenticated = "Authenticated"
        }
    }
}
