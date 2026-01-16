import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

/// View for editing an existing server's name and emoji
struct ServerEditView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let config: ServerConfiguration

    @State private var name: String
    @State private var emoji: String
    @State private var showingEmojiPicker = false

    init(config: ServerConfiguration) {
        self.config = config
        _name = State(initialValue: config.name)
        _emoji = State(initialValue: config.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showingEmojiPicker.toggle()
                        } label: {
                            ServerAvatar(emoji: emoji, size: 80)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    if showingEmojiPicker {
                        ServerEmojiPicker(selectedEmoji: $emoji, isExpanded: $showingEmojiPicker)
                    }
                }

                Section("Display Name") {
                    TextField("Server Name", text: $name)
                        .textContentType(.organizationName)
                }

                Section("Server Details") {
                    LabeledContent("Jellyfin URL") {
                        Text(config.jellyfinURL.absoluteString)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if let jellyseerrURL = config.jellyseerrURL {
                        LabeledContent("Jellyseerr URL") {
                            Text(jellyseerrURL.absoluteString)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } else {
                        LabeledContent("Jellyseerr") {
                            Text("Not configured")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        ReauthenticateView(config: config)
                    } label: {
                        Label("Re-authenticate", systemImage: "key")
                    }
                }
            }
            .navigationTitle("Edit Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        var updated = config
        updated.name = name
        updated.emoji = emoji
        appState.updateServer(updated)
        dismiss()
    }
}

/// View for re-authenticating with a server
private struct ReauthenticateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let config: ServerConfiguration

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Re-authenticate")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter your credentials for \(config.jellyfinHost)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
            }

            Section("Credentials") {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                Button {
                    Task {
                        await reauthenticate()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "Authenticating..." : "Authenticate")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading || username.isEmpty)
            }
        }
        .navigationTitle("Re-authenticate")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reauthenticate() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = JellyfinService(serverURL: config.jellyfinURL)
            let response = try await service.authenticate(
                username: username,
                password: password
            )

            let deviceID = await service.getDeviceID()
            appState.saveJellyfinCredentials(
                serverID: config.id,
                accessToken: response.accessToken,
                userID: response.user.id,
                deviceID: deviceID
            )

            dismiss()
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

#Preview {
    ServerEditView(
        config: ServerConfiguration(
            name: "Home Server",
            emoji: "🏠",
            jellyfinURL: URL(string: "https://jellyfin.home.local")!,
            jellyseerrURL: URL(string: "https://jellyseerr.home.local")
        )
    )
    .environmentObject(AppState())
}
