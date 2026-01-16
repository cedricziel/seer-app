import JellyfinClient
import JellyseerrClient
import SeerCore
import SeerUI
import SwiftUI

/// View for adding a new server with full authentication flow
struct AddServerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: SetupStep = .serverInfo
    @State private var serverName = ""
    @State private var serverEmoji = "🖥️"
    @State private var jellyfinURL = ""
    @State private var jellyfinUsername = ""
    @State private var jellyfinPassword = ""
    @State private var jellyseerrURL = ""
    @State private var jellyseerrAPIKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingEmojiPicker = false

    // Temporary storage for successful auth results
    @State private var serverConfig: ServerConfiguration?
    @State private var jellyfinService: JellyfinService?

    enum SetupStep {
        case serverInfo
        case jellyfinAuth
        case jellyseerrAuth
        case complete
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch currentStep {
                case .serverInfo:
                    ServerInfoStepView(
                        serverName: $serverName,
                        serverEmoji: $serverEmoji,
                        showingEmojiPicker: $showingEmojiPicker,
                        onContinue: { currentStep = .jellyfinAuth }
                    )
                case .jellyfinAuth:
                    JellyfinAuthStepView(
                        jellyfinURL: $jellyfinURL,
                        jellyfinUsername: $jellyfinUsername,
                        jellyfinPassword: $jellyfinPassword,
                        isLoading: isLoading,
                        onConnect: { Task { await connectToJellyfin() } },
                        onBack: { currentStep = .serverInfo }
                    )
                case .jellyseerrAuth:
                    JellyseerrAuthStepView(
                        jellyseerrURL: $jellyseerrURL,
                        jellyseerrAPIKey: $jellyseerrAPIKey,
                        isLoading: isLoading,
                        onConnect: { Task { await connectToJellyseerr() } },
                        onSkip: { currentStep = .complete }
                    )
                case .complete:
                    CompletionStepView(
                        serverEmoji: serverEmoji,
                        serverName: serverName,
                        jellyseerrURL: jellyseerrURL,
                        onDone: { completeSetup() }
                    )
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Actions

    private func connectToJellyfin() async {
        guard let url = URL(string: jellyfinURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Please enter a valid Jellyfin server URL"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let service = JellyfinService(serverURL: url)
            let response = try await service.authenticate(
                username: jellyfinUsername,
                password: jellyfinPassword
            )

            // Create server configuration
            let config = ServerConfiguration(
                name: serverName,
                emoji: serverEmoji,
                jellyfinURL: url,
                jellyfinUserID: response.user.id,
                lastUsed: Date(),
                createdAt: Date()
            )

            // Store temporarily
            serverConfig = config
            jellyfinService = service

            // Add to app state
            appState.addServer(config)

            // Save credentials
            let deviceID = await service.getDeviceID()
            appState.saveJellyfinCredentials(
                serverID: config.id,
                accessToken: response.accessToken,
                userID: response.user.id,
                deviceID: deviceID
            )

            currentStep = .jellyseerrAuth
        } catch let error as JellyfinService.JellyfinError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func connectToJellyseerr() async {
        guard let url = URL(string: jellyseerrURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Please enter a valid Jellyseerr server URL"
            return
        }

        guard let config = serverConfig else {
            errorMessage = "Server configuration not found"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let service = JellyseerrService(serverURL: url, apiKey: jellyseerrAPIKey)
            let userInfo = try await service.verifyAuth()

            // Set user permissions from Jellyseerr
            appState.setJellyseerrPermissions(userInfo.permissions)

            // Update server configuration with Jellyseerr URL
            var updatedConfig = config
            updatedConfig.jellyseerrURL = url
            appState.updateServer(updatedConfig)
            serverConfig = updatedConfig

            // Save Jellyseerr credentials
            appState.saveJellyseerrCredentials(serverID: config.id, apiKey: jellyseerrAPIKey)

            currentStep = .complete
        } catch let error as JellyseerrService.JellyseerrError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func completeSetup() {
        // Switch to the newly added server
        if let config = serverConfig {
            appState.switchServer(to: config.id)
        }
        dismiss()
    }
}

// MARK: - Server Info Step View

private struct ServerInfoStepView: View {
    @Binding var serverName: String
    @Binding var serverEmoji: String
    @Binding var showingEmojiPicker: Bool
    let onContinue: () -> Void

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Details")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Give your server a name and choose an icon.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        showingEmojiPicker.toggle()
                    } label: {
                        ServerAvatar(emoji: serverEmoji, size: 64)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)

                if showingEmojiPicker {
                    ServerEmojiPicker(selectedEmoji: $serverEmoji, isExpanded: $showingEmojiPicker)
                }
            }

            Section("Name") {
                TextField("Server Name", text: $serverName)
                    .textContentType(.organizationName)
            }

            Section {
                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .disabled(serverName.isEmpty)
            }
        }
    }
}

// MARK: - Jellyfin Auth Step View

private struct JellyfinAuthStepView: View {
    @Binding var jellyfinURL: String
    @Binding var jellyfinUsername: String
    @Binding var jellyfinPassword: String
    let isLoading: Bool
    let onConnect: () -> Void
    let onBack: () -> Void

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect to Jellyfin")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter your Jellyfin server details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
            }

            Section("Server") {
                TextField("Server URL", text: $jellyfinURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            Section("Credentials") {
                TextField("Username", text: $jellyfinUsername)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $jellyfinPassword)
                    .textContentType(.password)
            }

            Section {
                Button {
                    onConnect()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "Connecting..." : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading || jellyfinURL.isEmpty || jellyfinUsername.isEmpty)

                Button("Back") {
                    onBack()
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Jellyseerr Auth Step View

private struct JellyseerrAuthStepView: View {
    @Binding var jellyseerrURL: String
    @Binding var jellyseerrAPIKey: String
    let isLoading: Bool
    let onConnect: () -> Void
    let onSkip: () -> Void

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Jellyfin Connected")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)

                    Text("Connect to Jellyseerr")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Optionally connect to Jellyseerr to request new media.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
            }

            Section("Server") {
                TextField("Jellyseerr URL", text: $jellyseerrURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            Section("API Key") {
                SecureField("API Key", text: $jellyseerrAPIKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Text("You can find your API key in Jellyseerr Settings > General")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    onConnect()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "Connecting..." : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading || jellyseerrURL.isEmpty || jellyseerrAPIKey.isEmpty)

                Button("Skip for Now") {
                    onSkip()
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Completion Step View

private struct CompletionStepView: View {
    let serverEmoji: String
    let serverName: String
    let jellyseerrURL: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ServerAvatar(emoji: serverEmoji, size: 80)

            Text("Server Added!")
                .font(.title)
                .fontWeight(.bold)

            Text(serverName)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Jellyfin")
                    Spacer()
                    Text("Connected")
                        .foregroundStyle(.green)
                }
                .font(.subheadline)

                HStack {
                    Image(systemName: jellyseerrURL.isEmpty ? "xmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(jellyseerrURL.isEmpty ? Color.secondary : Color.green)
                    Text("Jellyseerr")
                    Spacer()
                    Text(jellyseerrURL.isEmpty ? "Not Connected" : "Connected")
                        .foregroundStyle(jellyseerrURL.isEmpty ? Color.secondary : Color.green)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    AddServerView()
        .environmentObject(AppState())
}
