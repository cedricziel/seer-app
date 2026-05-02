import Foundation
import OSLog

/// Routes incoming `flowmark://` URLs to in-app navigation state.
/// Wired to `ContentView.onOpenURL` and dispatched from the system
/// when an `OpensIntent` returns a flowmark URL.
///
/// Routes defined for v1:
///   - `flowmark://media/<id>` → open media detail / player for the
///     given cached `MediaItem.id`
///   - `flowmark://library`    → switch the main tab to Library
@MainActor
public final class FlowmarkURLRouter: ObservableObject {
    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "FlowmarkURLRouter")

    /// The tab to display. Bound from `ContentView`'s `@State`.
    @Published public var selectedTab: AppTab = .library

    /// The media id to navigate to inside the Library tab. Cleared
    /// after the navigation has been consumed.
    @Published public var pendingMediaID: String?

    public static let scheme = "flowmark"

    public init() {}

    public enum AppTab: Hashable, Sendable {
        case library
        case discover
        case search
        case requests
    }

    public enum RouteResult: Equatable, Sendable {
        case openMedia(id: String)
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
            return .openMedia(id: id)
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
        case .openMedia(let id):
            selectedTab = .library
            pendingMediaID = id
        case .openLibrary:
            selectedTab = .library
            pendingMediaID = nil
        case .unknown(let url):
            Self.logger.info("Unknown flowmark route: \(url.absoluteString)")
        }
        return result
    }
}
