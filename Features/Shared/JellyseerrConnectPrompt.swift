import JellyseerrClient
import SeerCore
import SeerUI
import SwiftUI

/// Reusable wrapper around `JellyseerrConnectCallout` that handles the
/// connect sheet lifecycle and credential persistence. Drop into any feature
/// view's "Jellyseerr not configured" branch.
struct JellyseerrConnectPrompt: View {
    let title: String
    let description: String
    let onSuccess: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isShowingSheet = false

    var body: some View {
        JellyseerrConnectCallout(
            title: title,
            description: description,
            onConnectTapped: { isShowingSheet = true }
        )
        .sheet(isPresented: $isShowingSheet) {
            JellyseerrConnectSheet(
                connector: connector,
                onSuccess: handleSuccess,
                onCancel: { isShowingSheet = false }
            )
        }
    }

    @MainActor
    @Sendable
    private func connector(url: URL, apiKey: String) async throws {
        let service = JellyseerrService(serverURL: url, apiKey: apiKey)
        let userInfo = try await service.verifyAuth()
        appState.setJellyseerrPermissions(userInfo.permissions)
        appState.saveJellyseerrCredentials(serverURL: url, apiKey: apiKey)
    }

    @MainActor
    private func handleSuccess() {
        isShowingSheet = false
        onSuccess()
    }
}
