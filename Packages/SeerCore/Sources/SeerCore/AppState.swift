import Foundation
import SwiftData
import SwiftUI

/// Global application state shared across the app
@MainActor
public final class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    // MARK: - App Intents

    /// Whether the user has opted in to Spotlight / Siri semantic indexing
    /// of cached media items. Per-device (NOT mirrored to iCloud KVS) to
    /// match the existing `DiagnosticsConsent` posture and the device-local
    /// nature of `CSSearchableIndex`. Defaults to `false`.
    @Published public var appIntentsIndexingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                appIntentsIndexingEnabled,
                forKey: AppIntentsKeys.indexingEnabled
            )
        }
    }

    /// UserDefaults keys for App Intents preferences. Kept on `AppState`
    /// for visibility; tests can read these directly to assert per-device
    /// persistence semantics.
    public enum AppIntentsKeys {
        public static let indexingEnabled = "appIntents.indexingEnabled"
    }

    // MARK: - Jellyseerr User State

    /// The current Jellyseerr user's permissions (stored as raw value)
    @Published public var jellyseerrUserPermissions: Int = 0

    /// Whether the current user can manage requests (approve/decline)
    public var canManageRequests: Bool {
        let permissions = JellyseerrPermissions(rawValue: jellyseerrUserPermissions)
        return permissions.canManageRequests
    }

    /// Whether the current user can request 4K content
    public var canRequest4K: Bool {
        let permissions = JellyseerrPermissions(rawValue: jellyseerrUserPermissions)
        return permissions.canRequest4K
    }

    /// Whether the current user is an admin
    public var isJellyseerrAdmin: Bool {
        let permissions = JellyseerrPermissions(rawValue: jellyseerrUserPermissions)
        return permissions.contains(.admin)
    }

    /// Update the Jellyseerr user permissions
    public func setJellyseerrPermissions(_ permissions: Int) {
        jellyseerrUserPermissions = permissions
    }

    /// Clear the Jellyseerr user permissions (on logout or server switch)
    public func clearJellyseerrPermissions() {
        jellyseerrUserPermissions = 0
    }

    // MARK: - SwiftData Context

    private var modelContext: ModelContext?

    /// Public read-only accessor for the SwiftData context. Allows
    /// feature-layer view models to upsert records into shared models
    /// (e.g., `RequestsViewModel` populating `CachedRequest` for the
    /// AppEntity query). Returns nil before `setModelContext` is called.
    public var sharedModelContext: ModelContext? {
        modelContext
    }

    // MARK: - Computed Properties (from SwiftData)

    public var servers: [ServerConfiguration] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<ServerConfiguration>(
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse), SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public var activeServer: ServerConfiguration? {
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<ServerConfiguration>(
            predicate: #Predicate { $0.isActive }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public var activeServerID: UUID? {
        activeServer?.id
    }

    /// Stable string key for the active server, used to scope per-server
    /// on-device records such as downloads and auto-download rules. This is
    /// the configuration UUID, never a host name: the host flips between the
    /// internal and external URL depending on the current network.
    public var activeServerKey: String? {
        activeServerID?.uuidString
    }

    /// Host-based keys earlier versions used for the active server's
    /// downloads. Used once to migrate existing rows to `activeServerKey`.
    public var legacyServerKeys: [String] {
        guard let server = activeServer else { return [] }
        return [server.jellyfinURL.host, server.internalJellyfinURL?.host].compactMap(\.self)
    }

    public var jellyfinServerURL: URL? {
        guard let server = activeServer else { return nil }
        return ServerURLResolver.shared.resolveJellyfinURL(for: server)
    }

    /// Whether currently using the internal URL for the active server
    public var isUsingInternalURL: Bool {
        guard let server = activeServer else { return false }
        return ServerURLResolver.shared.isUsingInternalURL(for: server)
    }

    public var jellyfinUserID: String? {
        activeServer?.jellyfinUserID
    }

    public var jellyfinAccessToken: String? {
        guard let serverID = activeServerID else { return nil }
        return KeychainManager.shared.getCredential(for: serverID, key: .jellyfinAccessToken)
    }

    public var jellyfinDeviceID: String? {
        guard let serverID = activeServerID else { return nil }
        return KeychainManager.shared.getCredential(for: serverID, key: .jellyfinDeviceID)
    }

    public var jellyseerrServerURL: URL? {
        activeServer?.jellyseerrURL
    }

    public var jellyseerrAPIKey: String? {
        guard let serverID = activeServerID else { return nil }
        return KeychainManager.shared.getCredential(for: serverID, key: .jellyseerrAPIKey)
    }

    public var sortedConfigurations: [ServerConfiguration] {
        servers
    }

    public var hasServers: Bool {
        !servers.isEmpty
    }

    /// Convenience struct for accessing Jellyfin credentials
    public struct JellyfinCredentials: Sendable {
        public let serverURL: URL
        public let accessToken: String
        public let userId: String
        public let deviceId: String
    }

    /// Combined Jellyfin credentials for convenience
    public var jellyfinCredentials: JellyfinCredentials? {
        guard let serverURL = jellyfinServerURL,
              let accessToken = jellyfinAccessToken,
              let userId = jellyfinUserID,
              let deviceId = jellyfinDeviceID
        else {
            return nil
        }
        return JellyfinCredentials(
            serverURL: serverURL,
            accessToken: accessToken,
            userId: userId,
            deviceId: deviceId
        )
    }

    /// Resolve credentials for a specific server id (not necessarily
    /// the currently active one). Used by App Intents that target a
    /// non-active server explicitly via a `ServerEntity` parameter.
    public func jellyfinCredentials(for serverID: UUID) -> JellyfinCredentials? {
        guard let server = configuration(for: serverID),
              let userID = server.jellyfinUserID,
              let token = KeychainManager.shared.getCredential(
                  for: serverID,
                  key: .jellyfinAccessToken
              ),
              let device = KeychainManager.shared.getCredential(
                  for: serverID,
                  key: .jellyfinDeviceID
              )
        else { return nil }
        let serverURL = ServerURLResolver.shared.resolveJellyfinURL(for: server)
        return JellyfinCredentials(
            serverURL: serverURL,
            accessToken: token,
            userId: userID,
            deviceId: device
        )
    }

    // MARK: - Initialization

    public init() {
        // ModelContext will be set via setModelContext
        appIntentsIndexingEnabled = UserDefaults.standard.bool(
            forKey: AppIntentsKeys.indexingEnabled
        )
    }

    /// Set the model context for SwiftData operations
    public func setModelContext(_ context: ModelContext) {
        modelContext = context
        updateAuthenticationState()
    }

    // MARK: - Server Management

    /// Switch to a different server
    public func switchServer(to serverID: UUID) {
        guard let context = modelContext else { return }

        // Deactivate all servers
        let allServers = servers
        for server in allServers {
            server.isActive = false
        }

        // Activate the selected server
        if let server = allServers.first(where: { $0.id == serverID }) {
            server.isActive = true
            server.lastUsed = Date()
        }

        try? context.save()
        objectWillChange.send()
        updateAuthenticationState()
        clearJellyseerrPermissions() // Permissions need to be re-fetched for the new server
    }

    /// Add a new server and optionally switch to it
    public func addServer(_ configuration: ServerConfiguration) {
        guard let context = modelContext else { return }

        context.insert(configuration)

        // If this is the first server, set it as active
        if servers.count == 1 || configuration.isActive {
            let allServers = servers
            for server in allServers where server.id != configuration.id {
                server.isActive = false
            }
            configuration.isActive = true
        }

        try? context.save()
        objectWillChange.send()
    }

    /// Update a server configuration
    public func updateServer(_: ServerConfiguration) {
        guard let context = modelContext else { return }
        try? context.save()
        objectWillChange.send()
    }

    /// Delete a server and its credentials
    public func deleteServer(_ configuration: ServerConfiguration) {
        guard let context = modelContext else { return }

        let wasActive = configuration.isActive
        KeychainManager.shared.deleteServerCredentials(for: configuration.id)
        context.delete(configuration)

        // If the deleted server was active, switch to another one
        if wasActive, let firstServer = servers.first {
            firstServer.isActive = true
        }

        try? context.save()
        objectWillChange.send()
        updateAuthenticationState()
    }

    /// Delete a server by ID
    public func deleteServer(id: UUID) {
        guard let server = servers.first(where: { $0.id == id }) else { return }
        deleteServer(server)
    }

    /// Get a configuration by ID
    public func configuration(for id: UUID) -> ServerConfiguration? {
        servers.first { $0.id == id }
    }

    /// Mark a server as recently used
    public func markAsUsed(_ id: UUID) {
        guard let context = modelContext,
              let server = servers.first(where: { $0.id == id })
        else { return }

        server.lastUsed = Date()
        try? context.save()
        objectWillChange.send()
    }

    // MARK: - Credential Management

    /// Update authentication state based on active server
    public func updateAuthenticationState() {
        guard let server = activeServer else {
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
        if let config = configuration(for: serverID) {
            config.jellyfinUserID = userID
            try? modelContext?.save()
            objectWillChange.send()
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
        if let existingServer = servers.first(where: { $0.jellyfinURL == serverURL }) {
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
            addServer(config)
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
        guard let serverID = activeServerID,
              let config = activeServer
        else {
            return
        }

        config.jellyseerrURL = serverURL
        try? modelContext?.save()
        objectWillChange.send()
        saveJellyseerrCredentials(serverID: serverID, apiKey: apiKey)
    }

    /// Clear all stored credentials and log out
    public func logout() {
        // Delete credentials for active server only
        if let serverID = activeServerID {
            KeychainManager.shared.deleteServerCredentials(for: serverID)
        }
        isAuthenticated = false
        clearJellyseerrPermissions()
    }

    /// Log out from all servers
    public func logoutAll() {
        for config in servers {
            KeychainManager.shared.deleteServerCredentials(for: config.id)
        }
        isAuthenticated = false
        clearJellyseerrPermissions()
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

    /// Load stored credentials (now handled by SwiftData)
    public func loadStoredCredentials() {
        updateAuthenticationState()
    }
}
