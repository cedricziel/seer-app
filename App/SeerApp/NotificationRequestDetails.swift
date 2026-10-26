import Combine
import Foundation
import JellyseerrClient
import SeerCore

@MainActor
final class NotificationRequestDetails: ObservableObject {
    @Published private(set) var request: MediaRequest?
    @Published private(set) var errorMessage: String?

    func clear(error: String? = nil) {
        request = nil
        errorMessage = error
    }

    func load(
        configuration: AppState.ServiceConfigurationID,
        currentConfiguration: () -> AppState.ServiceConfigurationID,
        fetch: () async throws -> MediaRequest
    ) async {
        clear()
        do {
            let loaded = try await fetch()
            guard !Task.isCancelled, currentConfiguration() == configuration else { return }
            request = loaded
        } catch {
            guard !Task.isCancelled, currentConfiguration() == configuration else { return }
            errorMessage = error.localizedDescription
        }
    }
}
