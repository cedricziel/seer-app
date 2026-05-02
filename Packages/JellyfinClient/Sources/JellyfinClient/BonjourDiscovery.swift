import Foundation
import Network

/// A Jellyfin server discovered on the local network via Bonjour.
public struct DiscoveredJellyfinServer: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let url: URL

    public init(id: String, name: String, host: String, port: Int, url: URL) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.url = url
    }
}

/// Events emitted by a `BonjourEngine`.
public enum BonjourDiscoveryEvent: Sendable {
    case discovered(DiscoveredJellyfinServer)
    case removed(DiscoveredJellyfinServer)
    case permissionDenied
}

/// Abstraction over the underlying Bonjour browser so production uses
/// `NWBrowser` and tests can substitute a deterministic stub.
public protocol BonjourEngine: AnyObject, Sendable {
    func start(handler: @escaping @Sendable (BonjourDiscoveryEvent) -> Void)
    func cancel()
}

/// Browses the local network for Jellyfin servers advertising
/// `_jellyfin._tcp` and exposes them as published state for SwiftUI.
@MainActor
public final class BonjourDiscovery: ObservableObject {
    @Published public private(set) var discoveredServers: [DiscoveredJellyfinServer] = []
    @Published public private(set) var permissionDenied: Bool = false

    private let engine: any BonjourEngine
    private var isRunning = false

    public init(engine: (any BonjourEngine)? = nil) {
        self.engine = engine ?? NWBrowserEngine()
    }

    nonisolated deinit {
        engine.cancel()
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        permissionDenied = false
        engine.start { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
    }

    public func stop() {
        guard isRunning else { return }
        engine.cancel()
        isRunning = false
    }

    private func handle(_ event: BonjourDiscoveryEvent) {
        switch event {
        case let .discovered(server):
            if !discoveredServers.contains(where: { $0.id == server.id }) {
                discoveredServers.append(server)
            }
        case let .removed(server):
            discoveredServers.removeAll { $0.id == server.id }
        case .permissionDenied:
            permissionDenied = true
        }
    }
}

/// Production engine backed by `NWBrowser` for `_jellyfin._tcp`.
final class NWBrowserEngine: BonjourEngine, @unchecked Sendable {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.cedricziel.seer.bonjour")

    func start(handler: @escaping @Sendable (BonjourDiscoveryEvent) -> Void) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_jellyfin._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)
        self.browser = browser

        browser.stateUpdateHandler = { state in
            if case let .failed(error) = state, case .dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied)) = error {
                handler(.permissionDenied)
            }
        }

        browser.browseResultsChangedHandler = { results, changes in
            for change in changes {
                switch change {
                case let .added(result):
                    if let server = Self.makeServer(from: result) {
                        handler(.discovered(server))
                    }
                case let .removed(result):
                    if let server = Self.makeServer(from: result) {
                        handler(.removed(server))
                    }
                default:
                    break
                }
            }
            _ = results
        }

        browser.start(queue: queue)
    }

    func cancel() {
        browser?.cancel()
        browser = nil
    }

    private static func makeServer(from result: NWBrowser.Result) -> DiscoveredJellyfinServer? {
        guard case let .service(name, _, _, _) = result.endpoint else { return nil }
        let host = "\(name).local"
        let port = 8096
        guard let url = URL(string: "http://\(host):\(port)") else { return nil }
        return DiscoveredJellyfinServer(id: name, name: name, host: host, port: port, url: url)
    }
}
