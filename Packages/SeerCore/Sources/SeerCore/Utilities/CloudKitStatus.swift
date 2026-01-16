import CloudKit
import Foundation

/// Monitors CloudKit account status for debugging sync issues
@MainActor
public class CloudKitStatus: ObservableObject {
    public static let containerIdentifier = "iCloud.com.cedricziel.seer"

    @Published public var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published public var errorMessage: String?
    @Published public var isChecking = false

    private let container: CKContainer

    public init() {
        container = CKContainer(identifier: Self.containerIdentifier)
    }

    public func checkStatus() async {
        isChecking = true
        errorMessage = nil

        do {
            accountStatus = try await container.accountStatus()
        } catch {
            errorMessage = error.localizedDescription
        }

        isChecking = false
    }

    /// Human-readable description of the account status
    public var statusDescription: String {
        switch accountStatus {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown Status"
        }
    }

    /// SF Symbol name for the current status
    public var statusIcon: String {
        switch accountStatus {
        case .available:
            return "checkmark.icloud.fill"
        case .noAccount:
            return "xmark.icloud.fill"
        case .restricted:
            return "lock.icloud.fill"
        case .couldNotDetermine:
            return "questionmark.icloud.fill"
        case .temporarilyUnavailable:
            return "exclamationmark.icloud.fill"
        @unknown default:
            return "icloud.slash.fill"
        }
    }

    /// Whether sync is expected to work
    public var isSyncAvailable: Bool {
        accountStatus == .available
    }
}
