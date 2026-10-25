import DownloadClient
import JellyseerrClient
import NotificationClient
import SeerCore
import SwiftUI

struct NotificationDestinationView: View {
    let destination: NotificationNavigation.Destination
    @EnvironmentObject private var appState: AppState
    @Environment(DownloadManager.self) private var downloadManager: DownloadManager?
    @Environment(\.dismiss) private var dismiss
    @State private var request: MediaRequest?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch destination {
            case let .request(_, requestID):
                if let request {
                    RequestDetailsSheet(
                        request: request,
                        displayTitle: request.media.displayTitle ?? "Request #\(requestID)"
                    )
                } else {
                    NavigationStack {
                        Group {
                            if let errorMessage {
                                ContentUnavailableView(
                                    "Request unavailable",
                                    systemImage: "exclamationmark.circle",
                                    description: Text(errorMessage)
                                )
                            } else {
                                ProgressView("Loading request...")
                            }
                        }
                        .toolbar { Button("Done") { dismiss() } }
                    }
                }
            case let .download(serverID, downloadID):
                NavigationStack {
                    Group {
                        if let manager = downloadManager,
                           let download = manager.downloads.first(where: {
                               $0.id == downloadID && $0.serverID == serverID.uuidString
                           }) {
                            List { DownloadRow(download: download, manager: manager) }
                        } else {
                            ContentUnavailableView(
                                "Download unavailable",
                                systemImage: "arrow.down.circle",
                                description: Text("This download may have been removed.")
                            )
                        }
                    }
                    .navigationTitle("Download")
                    .toolbar { Button("Done") { dismiss() } }
                }
            }
        }
        .task(id: destination.id) { await loadRequest() }
        .onChange(of: appState.activeServerID) { _, serverID in
            if serverID != destination.serverID {
                dismiss()
            }
        }
        .onChange(of: appState.isAuthenticated) { _, authenticated in
            if !authenticated {
                dismiss()
            }
        }
    }

    private func loadRequest() async {
        guard appState.activeServerID == destination.serverID, appState.isAuthenticated else { return }
        guard case let .request(serverID, requestID) = destination else {
            await downloadManager?.refresh()
            return
        }
        guard let url = appState.jellyseerrServerURL, let apiKey = appState.jellyseerrAPIKey else {
            errorMessage = "Jellyseerr is not configured for this server."
            return
        }
        do {
            let service = JellyseerrService(serverURL: url, apiKey: apiKey)
            let loaded = try await service.getRequest(id: requestID)
            guard !Task.isCancelled, appState.activeServerID == serverID, appState.isAuthenticated else { return }
            request = loaded
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
