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

/// Plain value copy of `NotificationPreferences`. This is what leaves the
/// persistence layer; `@Model` instances stay bound to the context that
/// fetched them.
public struct NotificationPreferenceValues: Sendable, Equatable {
    public var downloadCompletionEnabled: Bool
    public var downloadFailureEnabled: Bool
    public var requestApprovedEnabled: Bool
    public var requestAvailableEnabled: Bool
    public var requestDeclinedEnabled: Bool
    public var autoDownloadEnabled: Bool

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

extension NotificationPreferences {
    /// Snapshot of the stored row
    var values: NotificationPreferenceValues {
        NotificationPreferenceValues(
            downloadCompletionEnabled: downloadCompletionEnabled,
            downloadFailureEnabled: downloadFailureEnabled,
            requestApprovedEnabled: requestApprovedEnabled,
            requestAvailableEnabled: requestAvailableEnabled,
            requestDeclinedEnabled: requestDeclinedEnabled,
            autoDownloadEnabled: autoDownloadEnabled
        )
    }

    /// Copy values into the stored row
    func apply(_ values: NotificationPreferenceValues) {
        downloadCompletionEnabled = values.downloadCompletionEnabled
        downloadFailureEnabled = values.downloadFailureEnabled
        requestApprovedEnabled = values.requestApprovedEnabled
        requestAvailableEnabled = values.requestAvailableEnabled
        requestDeclinedEnabled = values.requestDeclinedEnabled
        autoDownloadEnabled = values.autoDownloadEnabled
    }

    convenience init(values: NotificationPreferenceValues) {
        self.init(
            downloadCompletionEnabled: values.downloadCompletionEnabled,
            downloadFailureEnabled: values.downloadFailureEnabled,
            requestApprovedEnabled: values.requestApprovedEnabled,
            requestAvailableEnabled: values.requestAvailableEnabled,
            requestDeclinedEnabled: values.requestDeclinedEnabled,
            autoDownloadEnabled: values.autoDownloadEnabled
        )
    }
}
