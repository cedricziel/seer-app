import Foundation
import SwiftUI

/// Global application state shared across the app
@MainActor
public final class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    // MARK: - Server Configuration Store

    @Published public var serverStore: ServerConfigStore

    // MARK: - Computed Properties (from active server)

    public var jellyfinServerURL: URL? {
        serverStore.activeServer?.jellyfinURL
    }

    public var jellyfinUserID: String? {
        serverStore.activeServer?.jellyfinUserID
    }

    public var jellyfinAccessToken: String? {
        guard let serverID = serverStore.activeServerID else { return nil }
        return KeychainManager.shared.getCredential(for: serverID, key: .jellyfinAccessToken)
    }

    public var jellyfinDeviceID: String? {
        guard let serverID = serverStore.activeServerID else { return nil }
        return KeychainManager.shared.getCredential(for: serverID, key: .jellyfinDeviceID)
    }

    public var jellyseerrServerURL: URL? {
        serverStore.activeServer?.jellyseerrURL
    }

    public var jellyseerrAPIKey: String? {
        guard let serverID = serverStore.activeServerID else { return nil }
        return KeychainManager.shared.getCredential(for: serverID, key: .jellyseerrAPIKey)
    }

    public var activeServer: ServerConfiguration? {
        serverStore.activeServer
    }

    public var servers: [ServerConfiguration] {
        serverStore.configurations
    }

    public var activeServerID: UUID? {
        serverStore.activeServerID
    }

    // MARK: - Initialization

    public init(serverStore: ServerConfigStore = ServerConfigStore()) {
        self.serverStore = serverStore
        updateAuthenticationState()
    }

    // MARK: - Server Management

    /// Switch to a different server
    public func switchServer(to serverID: UUID) {
        serverStore.setActiveServer(serverID)
        updateAuthenticationState()
    }

    /// Add a new server and switch to it
    public func addServer(_ configuration: ServerConfiguration) {
        serverStore.add(configuration)
    }

    /// Update a server configuration
    public func updateServer(_ configuration: ServerConfiguration) {
        serverStore.update(configuration)
    }

    /// Delete a server and its credentials
    public func deleteServer(_ configuration: ServerConfiguration) {
        KeychainManager.shared.deleteServerCredentials(for: configuration.id)
        serverStore.delete(configuration)
        updateAuthenticationState()
    }

    /// Delete a server by ID
    public func deleteServer(id: UUID) {
        KeychainManager.shared.deleteServerCredentials(for: id)
        serverStore.delete(id: id)
        updateAuthenticationState()
    }

    // MARK: - Credential Management

    /// Update authentication state based on active server
    public func updateAuthenticationState() {
        guard let server = serverStore.activeServer else {
            isAuthenticated = false
            return
        }

        let credentials = KeychainManager.shared.getServerCredentials(for: server.id)
        isAuthenticated = credentials.hasJellyfinCredentials
    }

    /// Save Jellyfin credentials for a server
    public func saveJellyfinCredentials(
        serverID: UUID,
        accessToken: String,
        userID: String,
        deviceID: String
    ) {
        let keychain = KeychainManager.shared
        keychain.saveCredential(accessToken, for: serverID, key: .jellyfinAccessToken)
        keychain.saveCredential(deviceID, for: serverID, key: .jellyfinDeviceID)

        // Update user ID in server configuration
        if var config = serverStore.configuration(for: serverID) {
            config.jellyfinUserID = userID
            serverStore.update(config)
        }

        updateAuthenticationState()
    }

    /// Save Jellyfin credentials (creates or updates server config)
    public func saveJellyfinCredentials(
        serverURL: URL,
        accessToken: String,
        userID: String,
        deviceID: String
    ) {
        // Find existing server or create new one
        if let existingServer = serverStore.configurations.first(where: { $0.jellyfinURL == serverURL }) {
            saveJellyfinCredentials(
                serverID: existingServer.id,
                accessToken: accessToken,
                userID: userID,
                deviceID: deviceID
            )
        } else {
            // This shouldn't happen in normal flow - server should be created first
            // But keep for backward compatibility
            let config = ServerConfiguration(
                name: serverURL.host ?? "Server",
                jellyfinURL: serverURL,
                jellyfinUserID: userID
            )
            serverStore.add(config)
            saveJellyfinCredentials(
                serverID: config.id,
                accessToken: accessToken,
                userID: userID,
                deviceID: deviceID
            )
        }
    }

    /// Save Jellyseerr credentials for a server
    public func saveJellyseerrCredentials(serverID: UUID, apiKey: String) {
        KeychainManager.shared.saveCredential(apiKey, for: serverID, key: .jellyseerrAPIKey)
    }

    /// Save Jellyseerr credentials (updates active server)
    public func saveJellyseerrCredentials(serverURL: URL, apiKey: String) {
        guard let serverID = serverStore.activeServerID,
              var config = serverStore.activeServer
        else {
            return
        }

        config.jellyseerrURL = serverURL
        serverStore.update(config)
        saveJellyseerrCredentials(serverID: serverID, apiKey: apiKey)
    }

    /// Clear all stored credentials and log out
    public func logout() {
        // Delete credentials for active server only
        if let serverID = serverStore.activeServerID {
            KeychainManager.shared.deleteServerCredentials(for: serverID)
        }
        isAuthenticated = false
    }

    /// Log out from all servers
    public func logoutAll() {
        for config in serverStore.configurations {
            KeychainManager.shared.deleteServerCredentials(for: config.id)
        }
        isAuthenticated = false
    }

    // MARK: - Migration

    /// Migrate legacy single-server credentials to multi-server format
    public func migrateLegacyCredentials() {
        let keychain = KeychainManager.shared

        guard keychain.hasLegacyCredentials(),
              let urlString = keychain.getString(for: .jellyfinServerURL),
              let jellyfinURL = URL(string: urlString)
        else {
            return
        }

        // Check if this server already exists
        if serverStore.configurations.contains(where: { $0.jellyfinURL == jellyfinURL }) {
            // Already migrated, just clean up legacy keys
            keychain.deleteAll()
            return
        }

        // Create new server configuration
        let userID = keychain.getString(for: .jellyfinUserID)
        var jellyseerrURL: URL?
        if let jellyseerrURLString = keychain.getString(for: .jellyseerrServerURL) {
            jellyseerrURL = URL(string: jellyseerrURLString)
        }

        let config = ServerConfiguration(
            name: jellyfinURL.host ?? "My Server",
            emoji: "🏠",
            jellyfinURL: jellyfinURL,
            jellyseerrURL: jellyseerrURL,
            jellyfinUserID: userID,
            lastUsed: Date(),
            createdAt: Date()
        )

        serverStore.add(config)

        // Migrate credentials
        if let accessToken = keychain.getString(for: .jellyfinAccessToken) {
            keychain.saveCredential(accessToken, for: config.id, key: .jellyfinAccessToken)
        }
        if let deviceID = keychain.getString(for: .jellyfinDeviceID) {
            keychain.saveCredential(deviceID, for: config.id, key: .jellyfinDeviceID)
        }
        if let apiKey = keychain.getString(for: .jellyseerrAPIKey) {
            keychain.saveCredential(apiKey, for: config.id, key: .jellyseerrAPIKey)
        }

        // Clean up legacy keys
        keychain.deleteAll()

        // Update authentication state
        updateAuthenticationState()
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

    // MARK: - Legacy Compatibility

    /// Load stored credentials (now handled by server store)
    public func loadStoredCredentials() {
        updateAuthenticationState()
    }
}
