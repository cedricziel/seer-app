import SeerCore
import SwiftUI

struct SettingsButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .accessibilityIdentifier("settingsButton")
        .sheet(isPresented: $isPresented) {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var destination: Destination?

    private enum Destination: String, Identifiable {
        case servers, downloads
        var id: String {
            rawValue
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Connections") {
                    Button {
                        destination = .servers
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Servers", systemImage: "server.rack")
                            if let server = appState.activeServer {
                                Text("Active: \(server.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Preferences") {
                    Button {
                        destination = .downloads
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("Privacy & Diagnostics", systemImage: "hand.raised")
                    }
                }

                Section("Help") {
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $destination) { destination in
                switch destination {
                case .servers: ServerManagementView()
                case .downloads: DownloadSettingsView()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 480, idealHeight: 560)
        #endif
    }
}
