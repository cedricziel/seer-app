import Foundation
import SwiftData

/// User preferences for notification types
@Model
public final class NotificationPreferences {
    // MARK: - Download Notifications

    /// Notify when downloads complete successfully
    public var downloadCompletionEnabled: Bool

    /// Notify when downloads fail
    public var downloadFailureEnabled: Bool

    // MARK: - Request Notifications

    /// Notify when a request is approved
    public var requestApprovedEnabled: Bool

    /// Notify when requested media becomes available
    public var requestAvailableEnabled: Bool

    /// Notify when a request is declined
    public var requestDeclinedEnabled: Bool

    // MARK: - Auto-Download Notifications

    /// Notify when auto-downloads complete
    public var autoDownloadEnabled: Bool

    // MARK: - Initialization

    public init(
        downloadCompletionEnabled: Bool = true,
        downloadFailureEnabled: Bool = true,
        requestApprovedEnabled: Bool = true,
        requestAvailableEnabled: Bool = true,
        requestDeclinedEnabled: Bool = true,
        autoDownloadEnabled: Bool = true
    ) {
        self.downloadCompletionEnabled = downloadCompletionEnabled
        self.downloadFailureEnabled = downloadFailureEnabled
        self.requestApprovedEnabled = requestApprovedEnabled
        self.requestAvailableEnabled = requestAvailableEnabled
        self.requestDeclinedEnabled = requestDeclinedEnabled
        self.autoDownloadEnabled = autoDownloadEnabled
    }
}

// SwiftData @Model classes need explicit Sendable conformance for cross-actor use
extension NotificationPreferences: @unchecked Sendable {}
