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

    // MARK: - Initialization

    public init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Jellyfin Authentication

    func connectToJellyfin() async {
        guard let url = URL(string: jellyfinServerURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            showErrorMessage("Please enter a valid Jellyfin server URL")
            return
        }

        guard !jellyfinUsername.isEmpty else {
            showErrorMessage("Please enter your username")
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

            // Save credentials
            await appState.saveJellyfinCredentials(
                serverURL: url,
                accessToken: response.accessToken,
                userID: response.user.id,
                deviceID: service.getDeviceID()
            )

            jellyfinService = service
            jellyfinConnected = true
            currentStep = .jellyseerr
        } catch let error as JellyfinService.JellyfinError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to connect: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Jellyseerr Authentication

    func connectToJellyseerr() async {
        guard let url = URL(string: jellyseerrServerURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            showErrorMessage("Please enter a valid Jellyseerr server URL")
            return
        }

        guard !jellyseerrAPIKey.isEmpty else {
            showErrorMessage("Please enter your API key")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let service = JellyseerrService(serverURL: url, apiKey: jellyseerrAPIKey)
            _ = try await service.verifyAuth()

            // Save credentials
            appState.saveJellyseerrCredentials(serverURL: url, apiKey: jellyseerrAPIKey)

            jellyseerrService = service
            jellyseerrConnected = true
            currentStep = .complete
        } catch let error as JellyseerrService.JellyseerrError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to connect: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func skipJellyseerr() {
        currentStep = .complete
    }

    func completeSetup() {
        appState.isAuthenticated = true
    }

    // MARK: - Error Handling

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}
