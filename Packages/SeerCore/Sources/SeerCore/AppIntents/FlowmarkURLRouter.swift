import Foundation
import OSLog

/// Routes incoming `flowmark://` URLs to in-app navigation state.
/// Wired to `SeerApp.onOpenURL` and dispatched from the system
/// when an `OpensIntent` returns a flowmark URL.
///
/// Routes defined for v1:
///   - `flowmark://media/<id>` → open media detail / player for the
///     given cached `MediaItem.id`
///   - `flowmark://library`    → switch the main tab to Library
@MainActor
public final class FlowmarkURLRouter: ObservableObject {
    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "FlowmarkURLRouter")

    /// The tab displayed by the main TabView.
    @Published public var selectedTab: AppTab = .library

    /// The Library detail target, retained until a successful navigation.
    @Published public private(set) var pendingMedia: MediaRoute?

    public struct MediaRoute: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let itemID: String
        public let serverID: UUID?
    }

    public nonisolated static let scheme = "flowmark"

    public init() {}

    public enum AppTab: Hashable, Sendable {
        case library
        case discover
        case search
        case requests
        case downloads
    }

    public enum RouteResult: Equatable, Sendable {
        case openMedia(id: String, serverID: UUID? = nil)
        case openLibrary
        case unknown(URL)
    }

    /// Parse the URL into a `RouteResult` without applying it. Useful
    /// in tests and for layered routing.
    public static func parse(_ url: URL) -> RouteResult {
        guard url.scheme?.lowercased() == scheme else {
            return .unknown(url)
        }

        // URL host carries the route name in `flowmark://route/...`
        // but `URLComponents` normalises differently for opaque hosts.
        let route = url.host ?? url.pathComponents.first ?? ""

        switch route.lowercased() {
        case "media":
            // Path components: ["/", "<id>"]; take the last non-slash piece.
            let id = url.pathComponents
                .filter { $0 != "/" && !$0.isEmpty }
                .last ?? ""
            guard !id.isEmpty else {
                return .unknown(url)
            }
            let serverValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "server" })?.value
            if let serverValue, UUID(uuidString: serverValue) == nil { return .unknown(url) }
            return .openMedia(id: id, serverID: serverValue.flatMap(UUID.init(uuidString:)))
        case "library":
            return .openLibrary
        default:
            return .unknown(url)
        }
    }

    /// Dispatch the URL into navigation state. Returns the parse
    /// result so callers can log or surface a UI hint.
    @discardableResult
    public func route(_ url: URL) -> RouteResult {
        let result = Self.parse(url)
        switch result {
        case let .openMedia(id, serverID):
            selectedTab = .library
            pendingMedia = MediaRoute(itemID: id, serverID: serverID)
        case .openLibrary:
            selectedTab = .library
            pendingMedia = nil
        case let .unknown(url):
            Self.logger.info("Unknown flowmark route: \(url.absoluteString)")
        }
        return result
    }

    /// Opens the resolved item once. Superseded routes and cancelled lookups cannot navigate.
    public func consumePendingMedia<Item>(
        resolve: (MediaRoute) async -> Item?,
        open: (Item) -> Void
    ) async {
        guard let route = pendingMedia,
              let item = await resolve(route),
              !Task.isCancelled, pendingMedia?.id == route.id else { return }
        pendingMedia = nil
        open(item)
    }
}
