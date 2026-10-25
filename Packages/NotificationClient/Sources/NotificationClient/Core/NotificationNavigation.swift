import Combine
import Foundation

/// Retains notification destinations until the authenticated UI can present them.
@MainActor
public final class NotificationNavigation: ObservableObject {
    public enum Destination: Equatable, Identifiable, Sendable {
        case request(serverID: UUID, requestID: Int)
        case download(serverID: UUID, downloadID: UUID)

        public var serverID: UUID {
            switch self {
            case let .request(serverID, _), let .download(serverID, _): serverID
            }
        }

        public var id: String {
            switch self {
            case let .request(serverID, requestID): "request-\(serverID)-\(requestID)"
            case let .download(serverID, downloadID): "download-\(serverID)-\(downloadID)"
            }
        }
    }

    @Published public private(set) var pendingDestination: Destination?

    public init() {}

    /// Rejects unscoped payloads rather than opening an ID on the wrong server.
    public func receive(category: NotificationCategory, info: NotificationInfo) {
        guard let key = info.serverID, let serverID = UUID(uuidString: key) else { return }
        switch category {
        case .requestStatusChanged:
            guard let requestID = info.requestID, requestID > 0 else { return }
            pendingDestination = .request(serverID: serverID, requestID: requestID)
        case .downloadCompleted, .downloadFailed:
            guard let downloadID = info.downloadID else { return }
            pendingDestination = .download(serverID: serverID, downloadID: downloadID)
        }
    }

    /// Consumes only after the destination server is active and authenticated.
    public func consume(activateServer: (UUID) -> Bool) -> Destination? {
        guard let destination = pendingDestination, activateServer(destination.serverID) else { return nil }
        pendingDestination = nil
        return destination
    }

    public func clear() {
        pendingDestination = nil
    }
}
