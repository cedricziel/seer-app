import SeerCore
import SeerUI
import SwiftUI

/// Sheet view for quickly switching between servers
struct ServerSwitcherView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddServer = false
    @State private var showingManageServers = false

    var body: some View {
        NavigationStack {
            List {
                // Server list
                Section {
                    ForEach(appState.sortedConfigurations) { config in
                        Button {
                            appState.switchServer(to: config.id)
                            dismiss()
                        } label: {
                            ServerRowView(
                                name: config.name,
                                emoji: config.emoji,
                                jellyfinHost: config.jellyfinHost,
                                jellyseerrHost: config.jellyseerrHost,
                                isActive: config.id == appState.activeServerID
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // Actions
                Section {
                    Button {
                        showingAddServer = true
                    } label: {
                        Label("Add New Server", systemImage: "plus")
                    }

                    Button {
                        showingManageServers = true
                    } label: {
                        Label("Manage Servers", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Switch Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                AddServerView()
            }
            .sheet(isPresented: $showingManageServers) {
                ServerManagementView()
            }
        }
    }
}

#Preview {
    ServerSwitcherView()
        .environmentObject(AppState())
}
