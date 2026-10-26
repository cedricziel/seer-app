import Foundation
import Observation

@MainActor
@Observable
final class DownloadActionFeedback {
    var message: String?

    func perform(_ action: () async throws -> Void) async {
        do {
            try await action()
        } catch {
            message = error.localizedDescription
        }
    }
}
