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
        #if os(tvOS)
            tvOSBody
        #else
            iOSBody
        #endif
    }

    #if os(tvOS)
        private var tvOSBody: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 20) {
                            ForEach(appState.sortedConfigurations) { config in
                                Button {
                                    appState.switchServer(to: config.id)
                                    dismiss()
                                } label: {
                                    tvOSServerRow(for: config)
                                }
                            }
                        }

                        VStack(spacing: 20) {
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
                    .frame(maxWidth: 960)
                    .padding(.vertical, 48)
                }
                .frame(maxWidth: .infinity)
                .navigationTitle("Switch Server")
                .sheet(isPresented: $showingAddServer) {
                    AddServerView()
                }
                .sheet(isPresented: $showingManageServers) {
                    ServerManagementView()
                }
            }
        }

        private func tvOSServerRow(for config: ServerConfiguration) -> some View {
            HStack(spacing: 24) {
                ServerAvatar(emoji: config.emoji, size: 72)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.title3)
                        .fontWeight(.medium)

                    Text(config.jellyfinHost)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let jellyseerrHost = config.jellyseerrHost {
                        Text("+ \(jellyseerrHost)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if config.id == appState.activeServerID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(tvOSServerAccessibilityLabel(for: config))
            .accessibilityAddTraits(config.id == appState.activeServerID ? [.isSelected] : [])
        }

        private func tvOSServerAccessibilityLabel(for config: ServerConfiguration) -> String {
            var label = "\(config.name), \(config.jellyfinHost)"
            if let jellyseerrHost = config.jellyseerrHost {
                label += ", with Jellyseerr at \(jellyseerrHost)"
            }
            if config.id == appState.activeServerID {
                label += ", active"
            }
            return label
        }
    #endif

    #if os(iOS)
        private var iOSBody: some View {
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
    #endif
}

#Preview {
    ServerSwitcherView()
        .environmentObject(AppState())
}
