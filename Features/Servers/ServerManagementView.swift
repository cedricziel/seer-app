import SeerCore
import SeerUI
import SwiftUI

/// Full-screen view for managing all server configurations
struct ServerManagementView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var serverToEdit: ServerConfiguration?
    @State private var showingAddServer = false
    @State private var serverToDelete: ServerConfiguration?

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.sortedConfigurations) { config in
                    ServerManagementRow(
                        config: config,
                        isActive: config.id == appState.activeServerID,
                        onEdit: {
                            serverToEdit = config
                        }
                    )
                }
                .onDelete(perform: deleteServers)

                Section {
                    Text("Swipe left on a server to delete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Manage Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddServer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $serverToEdit) { config in
                ServerEditView(config: config)
            }
            .sheet(isPresented: $showingAddServer) {
                AddServerView()
            }
            .alert(
                "Delete Server?",
                isPresented: .init(
                    get: { serverToDelete != nil },
                    set: { if !$0 { serverToDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    serverToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let server = serverToDelete {
                        appState.deleteServer(server)
                    }
                    serverToDelete = nil
                }
            } message: {
                if let server = serverToDelete {
                    Text("Are you sure you want to delete \"\(server.name)\"? This will remove all stored credentials.")
                }
            }
        }
    }

    private func deleteServers(at offsets: IndexSet) {
        let sorted = appState.sortedConfigurations
        for index in offsets {
            serverToDelete = sorted[index]
        }
    }
}

/// Row view for server management list
private struct ServerManagementRow: View {
    let config: ServerConfiguration
    let isActive: Bool
    let onEdit: () -> Void

    private var lastUsedText: String {
        guard let lastUsed = config.lastUsed else {
            return "Never used"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Used \(formatter.localizedString(for: lastUsed, relativeTo: Date()))"
    }

    var body: some View {
        HStack(spacing: 12) {
            ServerAvatar(emoji: config.emoji, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.name)
                        .font(.body)
                        .fontWeight(.medium)

                    if isActive {
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.2))
                            .foregroundStyle(.tint)
                            .clipShape(Capsule())
                    }
                }

                Text(config.jellyfinHost)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if config.hasJellyseerr {
                        Label("Jellyseerr", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Label("No Jellyseerr", systemImage: "xmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(lastUsedText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Text("Edit")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ServerManagementView()
        .environmentObject(AppState())
}
