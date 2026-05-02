import Foundation
import JellyfinClient
import JellyseerrClient
import SeerCore
import SwiftUI

/// View model for handling authentication
@MainActor
public final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var jellyfinServerURL: String = ""
    @Published var jellyfinUsername: String = ""
    @Published var jellyfinPassword: String = ""

    @Published var jellyseerrServerURL: String = ""
    @Published var jellyseerrAPIKey: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var errorSuggestion: String?
    @Published var showError: Bool = false

    @Published var jellyfinConnected: Bool = false
    @Published var jellyseerrConnected: Bool = false

    @Published var currentStep: SetupStep = .jellyfin

    enum SetupStep {
        case jellyfin
        case jellyseerr
        case complete
    }

    // MARK: - Private Properties

    private var jellyfinService: JellyfinService?
    private var jellyseerrService: JellyseerrService?
    private let appState: AppState
    private var serverConfig: ServerConfiguration?

    // MARK: - Initialization

    public init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Jellyfin Authentication

    func connectToJellyfin() async {
        let trimmedURL = jellyfinServerURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if let advice = AuthErrorFormatter.validate(urlString: trimmedURL) {
            showErrorAdvice(advice)
            return
        }

        guard let url = URL(string: trimmedURL) else {
            showErrorMessage("Please enter a valid Jellyfin server URL")
            return
        }

        guard !jellyfinUsername.isEmpty else {
            showErrorMessage("Please enter your username")
            return
        }

        isLoading = true
        clearError()

        do {
            try await performJellyfinLogin(url: url)
            jellyfinConnected = true
            currentStep = .jellyseerr
        } catch let error as JellyfinService.JellyfinError {
            handleJellyfinError(error, urlString: trimmedURL)
        } catch {
            showErrorAdvice(AuthErrorFormatter.advice(for: error, urlString: trimmedURL))
        }

        isLoading = false
    }

    private func performJellyfinLogin(url: URL) async throws {
        let service = JellyfinService(serverURL: url)
        let response = try await service.authenticate(
            username: jellyfinUsername,
            password: jellyfinPassword
        )

        let config = ServerConfiguration(
            name: url.host ?? "Server",
            emoji: "🏠",
            jellyfinURL: url,
            jellyfinUserID: response.user.id,
            lastUsed: Date(),
            createdAt: Date()
        )
        appState.addServer(config)
        serverConfig = config

        let deviceID = await service.getDeviceID()
        appState.saveJellyfinCredentials(
            serverID: config.id,
            accessToken: response.accessToken,
            userID: response.user.id,
            deviceID: deviceID
        )

        jellyfinService = service
    }

    private func handleJellyfinError(_ error: JellyfinService.JellyfinError, urlString: String) {
        switch error {
        case .invalidCredentials:
            showErrorAdvice(AuthErrorAdvice(
                message: "Invalid username or password",
                suggestion: "Check your Jellyfin credentials and try again"
            ))
        case let .networkError(underlying):
            showErrorAdvice(AuthErrorFormatter.advice(for: underlying, urlString: urlString))
        default:
            showErrorMessage(error.localizedDescription)
        }
    }

    // MARK: - Jellyseerr Authentication

    func connectToJellyseerr() async {
        let trimmedURL = jellyseerrServerURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if let advice = AuthErrorFormatter.validate(urlString: trimmedURL) {
            showErrorAdvice(advice)
            return
        }

        guard let url = URL(string: trimmedURL) else {
            showErrorMessage("Please enter a valid Jellyseerr server URL")
            return
        }

        guard !jellyseerrAPIKey.isEmpty else {
            showErrorMessage("Please enter your API key")
            return
        }

        guard var config = serverConfig else {
            showErrorMessage("Server configuration not found")
            return
        }

        isLoading = true
        clearError()

        do {
            let service = JellyseerrService(serverURL: url, apiKey: jellyseerrAPIKey)
            let userInfo = try await service.verifyAuth()

            // Set user permissions from Jellyseerr
            appState.setJellyseerrPermissions(userInfo.permissions)

            // Update server configuration with Jellyseerr URL
            config.jellyseerrURL = url
            appState.updateServer(config)
            serverConfig = config

            // Save Jellyseerr credentials
            appState.saveJellyseerrCredentials(serverID: config.id, apiKey: jellyseerrAPIKey)

            jellyseerrService = service
            jellyseerrConnected = true
            currentStep = .complete
        } catch let error as JellyseerrService.JellyseerrError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorAdvice(AuthErrorFormatter.advice(for: error, urlString: trimmedURL))
        }

        isLoading = false
    }

    func skipJellyseerr() {
        currentStep = .complete
    }

    func completeSetup() {
        // Switch to the newly configured server
        if let config = serverConfig {
            appState.switchServer(to: config.id)
        }
        appState.isAuthenticated = true
    }

    // MARK: - Error Handling

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        errorSuggestion = nil
        showError = true
    }

    private func showErrorAdvice(_ advice: AuthErrorAdvice) {
        errorMessage = advice.message
        errorSuggestion = advice.suggestion
        showError = true
    }

    func clearError() {
        errorMessage = nil
        errorSuggestion = nil
        showError = false
    }
}
