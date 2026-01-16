import Combine
import Foundation

/// Manages server configurations with iCloud sync via NSUbiquitousKeyValueStore
@MainActor
public final class ServerConfigStore: ObservableObject {
    // MARK: - Keys

    private enum StoreKey {
        static let configurations = "server_configurations"
        static let activeServerID = "active_server_id"
    }

    // MARK: - Published Properties

    @Published public private(set) var configurations: [ServerConfiguration] = []
    @Published public private(set) var activeServerID: UUID?

    // MARK: - Computed Properties

    public var activeServer: ServerConfiguration? {
        guard let id = activeServerID else { return nil }
        return configurations.first { $0.id == id }
    }

    public var sortedConfigurations: [ServerConfiguration] {
        configurations.sorted { config1, config2 in
            // Sort by last used date (most recent first), then by name
            if let date1 = config1.lastUsed, let date2 = config2.lastUsed {
                return date1 > date2
            } else if config1.lastUsed != nil {
                return true
            } else if config2.lastUsed != nil {
                return false
            }
            return config1.name.localizedCaseInsensitiveCompare(config2.name) == .orderedAscending
        }
    }

    // MARK: - Private Properties

    private let store: NSUbiquitousKeyValueStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        loadFromStore()
        observeStoreChanges()
        store.synchronize()
    }

    // MARK: - Public Methods

    /// Add a new server configuration
    public func add(_ configuration: ServerConfiguration) {
        configurations.append(configuration)
        saveToStore()

        // If this is the first server, set it as active
        if configurations.count == 1 {
            setActiveServer(configuration.id)
        }
    }

    /// Update an existing server configuration
    public func update(_ configuration: ServerConfiguration) {
        guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else {
            return
        }
        configurations[index] = configuration
        saveToStore()
    }

    /// Delete a server configuration
    public func delete(_ configuration: ServerConfiguration) {
        configurations.removeAll { $0.id == configuration.id }
        saveToStore()

        // If the deleted server was active, switch to another one
        if activeServerID == configuration.id {
            activeServerID = configurations.first?.id
            saveActiveServerID()
        }
    }

    /// Delete a server configuration by ID
    public func delete(id: UUID) {
        guard let config = configurations.first(where: { $0.id == id }) else { return }
        delete(config)
    }

    /// Set the active server
    public func setActiveServer(_ id: UUID?) {
        guard id != activeServerID else { return }
        activeServerID = id

        // Update last used timestamp
        if let id, let index = configurations.firstIndex(where: { $0.id == id }) {
            configurations[index].lastUsed = Date()
            saveToStore()
        }

        saveActiveServerID()
    }

    /// Mark a server as recently used
    public func markAsUsed(_ id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].lastUsed = Date()
        saveToStore()
    }

    /// Get a configuration by ID
    public func configuration(for id: UUID) -> ServerConfiguration? {
        configurations.first { $0.id == id }
    }

    /// Check if any servers are configured
    public var hasServers: Bool {
        !configurations.isEmpty
    }

    // MARK: - Private Methods

    private func loadFromStore() {
        // Load configurations
        if let data = store.data(forKey: StoreKey.configurations) {
            do {
                let decoder = JSONDecoder()
                configurations = try decoder.decode([ServerConfiguration].self, from: data)
            } catch {
                print("Failed to decode server configurations: \(error)")
                configurations = []
            }
        }

        // Load active server ID
        if let idString = store.string(forKey: StoreKey.activeServerID),
           let id = UUID(uuidString: idString)
        {
            activeServerID = id
        } else if let firstConfig = configurations.first {
            // Default to first server if none set
            activeServerID = firstConfig.id
        }
    }

    private func saveToStore() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(configurations)
            store.set(data, forKey: StoreKey.configurations)
            store.synchronize()
        } catch {
            print("Failed to encode server configurations: \(error)")
        }
    }

    private func saveActiveServerID() {
        if let id = activeServerID {
            store.set(id.uuidString, forKey: StoreKey.activeServerID)
        } else {
            store.removeObject(forKey: StoreKey.activeServerID)
        }
        store.synchronize()
    }

    private func observeStoreChanges() {
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.handleExternalChange(notification)
        }
        .store(in: &cancellables)
    }

    private func handleExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        else {
            return
        }

        // Handle different change reasons
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // Reload from store when external changes occur
            loadFromStore()

        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            print("Warning: iCloud Key-Value Store quota exceeded")

        case NSUbiquitousKeyValueStoreAccountChange:
            // Account changed, reload
            loadFromStore()

        default:
            break
        }
    }
}
