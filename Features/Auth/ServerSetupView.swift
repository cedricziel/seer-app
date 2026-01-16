import SeerCore
import SeerUI
import SwiftUI

/// View for setting up server connections
struct ServerSetupView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ServerSetupContentView(appState: appState)
    }
}

/// Internal view that creates the view model with the correct AppState
private struct ServerSetupContentView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: AuthViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: AuthViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.currentStep {
                case .jellyfin:
                    jellyfinSetupView
                case .jellyseerr:
                    jellyseerrSetupView
                case .complete:
                    setupCompleteView
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
        .onAppear {
            // Pre-fill with existing URLs if available
            if viewModel.jellyfinServerURL.isEmpty {
                viewModel.jellyfinServerURL = appState.jellyfinServerURL?.absoluteString ?? ""
                viewModel.jellyseerrServerURL = appState.jellyseerrServerURL?.absoluteString ?? ""
            }
        }
    }

    // MARK: - Jellyfin Setup

    private var jellyfinSetupView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect to Jellyfin")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter your Jellyfin server details to get started.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
            }

            Section("Server") {
                TextField("Server URL", text: $viewModel.jellyfinServerURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            Section("Credentials") {
                TextField("Username", text: $viewModel.jellyfinUsername)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $viewModel.jellyfinPassword)
                    .textContentType(.password)
            }

            Section {
                Button(action: {
                    Task {
                        await viewModel.connectToJellyfin()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(viewModel.isLoading ? "Connecting..." : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isLoading || viewModel.jellyfinServerURL.isEmpty || viewModel.jellyfinUsername.isEmpty)
            }
        }
    }

    // MARK: - Jellyseerr Setup

    private var jellyseerrSetupView: some View {
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
                TextField("Jellyseerr URL", text: $viewModel.jellyseerrServerURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            Section("API Key") {
                SecureField("API Key", text: $viewModel.jellyseerrAPIKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Text("You can find your API key in Jellyseerr Settings > General")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(action: {
                    Task {
                        await viewModel.connectToJellyseerr()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(viewModel.isLoading ? "Connecting..." : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isLoading || viewModel.jellyseerrServerURL.isEmpty || viewModel.jellyseerrAPIKey.isEmpty)

                Button("Skip for Now") {
                    viewModel.skipJellyseerr()
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Setup Complete

    private var setupCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Setup Complete!")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                connectionStatusRow(
                    title: "Jellyfin",
                    isConnected: viewModel.jellyfinConnected
                )

                connectionStatusRow(
                    title: "Jellyseerr",
                    isConnected: viewModel.jellyseerrConnected
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: {
                viewModel.completeSetup()
            }) {
                Text("Get Started")
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

    private func connectionStatusRow(title: String, isConnected: Bool) -> some View {
        HStack {
            Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(isConnected ? .green : .secondary)

            Text(title)
                .font(.body)

            Spacer()

            Text(isConnected ? "Connected" : "Not Connected")
                .font(.subheadline)
                .foregroundStyle(isConnected ? .green : .secondary)
        }
    }
}

#Preview {
    ServerSetupView()
        .environmentObject(AppState())
}
