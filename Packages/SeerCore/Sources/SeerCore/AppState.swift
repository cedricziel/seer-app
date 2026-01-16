import Foundation
import SwiftUI

/// Global application state shared across the app
@MainActor
public final class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    // MARK: - Jellyfin State

    @Published public var jellyfinServerURL: URL?
    @Published public var jellyfinUserID: String?
    @Published public var jellyfinAccessToken: String?
    @Published public var jellyfinDeviceID: String?

    // MARK: - Jellyseerr State

    @Published public var jellyseerrServerURL: URL?
    @Published public var jellyseerrAPIKey: String?

    // MARK: - Initialization

    public init() {
        loadStoredCredentials()
    }

    // MARK: - Credential Management

    /// Load stored credentials from Keychain
    public func loadStoredCredentials() {
        let keychain = KeychainManager.shared

        if let urlString = keychain.getString(for: .jellyfinServerURL) {
            jellyfinServerURL = URL(string: urlString)
        }
        jellyfinAccessToken = keychain.getString(for: .jellyfinAccessToken)
        jellyfinUserID = keychain.getString(for: .jellyfinUserID)
        jellyfinDeviceID = keychain.getString(for: .jellyfinDeviceID)

        if let urlString = keychain.getString(for: .jellyseerrServerURL) {
            jellyseerrServerURL = URL(string: urlString)
        }
        jellyseerrAPIKey = keychain.getString(for: .jellyseerrAPIKey)

        // User is authenticated if they have Jellyfin credentials
        isAuthenticated = jellyfinServerURL != nil && jellyfinAccessToken != nil
    }

    /// Save Jellyfin credentials to Keychain
    public func saveJellyfinCredentials(
        serverURL: URL,
        accessToken: String,
        userID: String,
        deviceID: String
    ) {
        let keychain = KeychainManager.shared
        keychain.save(serverURL.absoluteString, for: .jellyfinServerURL)
        keychain.save(accessToken, for: .jellyfinAccessToken)
        keychain.save(userID, for: .jellyfinUserID)
        keychain.save(deviceID, for: .jellyfinDeviceID)

        jellyfinServerURL = serverURL
        jellyfinAccessToken = accessToken
        jellyfinUserID = userID
        jellyfinDeviceID = deviceID
        isAuthenticated = true
    }

    /// Save Jellyseerr credentials to Keychain
    public func saveJellyseerrCredentials(serverURL: URL, apiKey: String) {
        let keychain = KeychainManager.shared
        keychain.save(serverURL.absoluteString, for: .jellyseerrServerURL)
        keychain.save(apiKey, for: .jellyseerrAPIKey)

        jellyseerrServerURL = serverURL
        jellyseerrAPIKey = apiKey
    }

    /// Clear all stored credentials and log out
    public func logout() {
        KeychainManager.shared.deleteAll()
        jellyfinServerURL = nil
        jellyfinAccessToken = nil
        jellyfinUserID = nil
        jellyfinDeviceID = nil
        jellyseerrServerURL = nil
        jellyseerrAPIKey = nil
        isAuthenticated = false
    }

    // MARK: - Error Handling

    /// Show an error message
    public func showError(_ message: String) {
        errorMessage = message
    }

    /// Clear the current error message
    public func clearError() {
        errorMessage = nil
    }
}
