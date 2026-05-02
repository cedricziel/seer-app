import Combine
import Foundation
import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

/// View model for the first-run onboarding flow. Coordinates Bonjour
/// discovery, Quick Connect, manual URL entry, and password fallback.
@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Phase: Equatable {
        case welcome
        case manualEntry
        case quickConnect(serverDisplay: String)
        case password(serverDisplay: String)
        case completing
    }

    struct SelectedServer: Equatable {
        let displayName: String
        let url: URL
        let discoveredViaBonjour: Bool
    }

    // MARK: - Welcome state

    @Published private(set) var phase: Phase = .welcome

    // MARK: - Manual entry

    @Published var manualURL: String = ""
    @Published private(set) var isValidatingManualURL: Bool = false
    @Published private(set) var manualURLError: String?

    // MARK: - Quick Connect

    @Published private(set) var quickConnectCode: String?
    @Published private(set) var quickConnectIsPolling: Bool = false
    @Published private(set) var quickConnectError: String?

    // MARK: - Password

    @Published var passwordUsername: String = ""
    @Published var passwordPassword: String = ""
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var passwordError: String?

    // MARK: - Dependencies

    typealias QuickConnectTransportFactory = @MainActor (URL) -> any QuickConnectTransport

    struct PasswordAuthResult {
        let response: AuthResponse
        let deviceID: String
    }

    typealias PasswordAuthenticator = @MainActor (URL, String, String) async throws -> PasswordAuthResult

    private let appState: AppState
    private let onboardingManager: OnboardingManager
    let bonjour: BonjourDiscovery
    private let serverInfoFetcher: ServerInfoFetcher
    private let resolver: WelcomeStateResolver
    private let quickConnectTransportFactory: QuickConnectTransportFactory
    private let passwordAuthenticator: PasswordAuthenticator

    private(set) var selectedServer: SelectedServer?
    private var quickConnectSession: QuickConnectSession?
    private var quickConnectStateObservation: AnyCancellable?

    // MARK: - Init

    init(
        appState: AppState,
        onboardingManager: OnboardingManager,
        bonjour: BonjourDiscovery? = nil,
        serverInfoFetcher: ServerInfoFetcher = ServerInfoFetcher(),
        quickConnectTransportFactory: QuickConnectTransportFactory? = nil,
        passwordAuthenticator: PasswordAuthenticator? = nil
    ) {
        self.appState = appState
        self.onboardingManager = onboardingManager
        self.bonjour = bonjour ?? BonjourDiscovery()
        self.serverInfoFetcher = serverInfoFetcher
        self.quickConnectTransportFactory = quickConnectTransportFactory
            ?? Self.defaultQuickConnectTransportFactory
        self.passwordAuthenticator = passwordAuthenticator
            ?? Self.defaultPasswordAuthenticator
        resolver = WelcomeStateResolver()
    }

    @MainActor
    private static func defaultQuickConnectTransportFactory(_: URL) -> any QuickConnectTransport {
        URLSessionQuickConnectTransport(deviceID: ClientIdentity.deviceID)
    }

    @MainActor
    private static func defaultPasswordAuthenticator(
        url: URL,
        username: String,
        password: String
    ) async throws -> PasswordAuthResult {
        let service = JellyfinService(serverURL: url)
        let response = try await service.authenticate(username: username, password: password)
        let deviceID = await service.getDeviceID()
        return PasswordAuthResult(response: response, deviceID: deviceID)
    }

    func start() {
        bonjour.start()
        TelemetryService.shared.recordOnboardingWelcomeShown()
    }

    func stop() {
        bonjour.stop()
        quickConnectSession?.cancel()
        quickConnectStateObservation = nil
    }

    // MARK: - Welcome

    /// Maps current `appState.servers` + Bonjour discoveries through the
    /// resolver and returns the data the `WelcomeView` needs.
    var welcomeSuggestions: (primary: WelcomeView.Suggestion?, secondary: [WelcomeView.Suggestion]) {
        let synced = appState.servers.map { config in
            WelcomeSuggestion(
                id: "synced-\(config.id.uuidString)",
                title: config.name,
                subtitle: "Sign back in",
                source: .synced,
                symbolName: "icloud.fill"
            )
        }
        let discovered = bonjour.discoveredServers.map { server in
            WelcomeSuggestion(
                id: "bonjour-\(server.id)",
                title: server.name,
                subtitle: "\(server.host) · on this Wi-Fi",
                source: .bonjour,
                symbolName: "wifi"
            )
        }
        let state = resolver.resolve(synced: synced, bonjour: discovered)
        let primary: WelcomeView.Suggestion? = switch state.primary {
        case .manualEntry: nil
        case let .suggestion(suggestion): Self.toViewSuggestion(suggestion)
        }
        return (primary, state.secondary.map(Self.toViewSuggestion))
    }

    func selectSuggestion(_ viewSuggestion: WelcomeView.Suggestion) {
        // Map the view's id back to an actual server (synced config or
        // discovered host) and advance to the auth phase.
        if viewSuggestion.id.hasPrefix("bonjour-") {
            let bonjourID = String(viewSuggestion.id.dropFirst("bonjour-".count))
            guard let discovered = bonjour.discoveredServers.first(where: { $0.id == bonjourID })
            else { return }
            selectedServer = SelectedServer(
                displayName: discovered.name,
                url: discovered.url,
                discoveredViaBonjour: true
            )
            TelemetryService.shared.recordOnboardingPathSelected(.bonjour)
            Task { await advanceToAuth() }
        } else if viewSuggestion.id.hasPrefix("synced-") {
            let uuidString = String(viewSuggestion.id.dropFirst("synced-".count))
            guard let uuid = UUID(uuidString: uuidString),
                  let config = appState.servers.first(where: { $0.id == uuid })
            else { return }
            selectedServer = SelectedServer(
                displayName: config.name,
                url: config.jellyfinURL,
                discoveredViaBonjour: false
            )
            TelemetryService.shared.recordOnboardingPathSelected(.icloud)
            Task { await advanceToAuth() }
        }
    }

    func tapManualEntry() {
        phase = .manualEntry
        manualURLError = nil
        TelemetryService.shared.recordOnboardingPathSelected(.manual)
    }

    // MARK: - Manual entry

    func validateManualURLAndAdvance() async {
        let trimmed = manualURL.trimmingCharacters(in: .whitespaces)
        guard let parsed = URL(string: trimmed),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              parsed.host != nil
        else {
            manualURLError = "Please enter a valid URL (https://...)."
            return
        }

        isValidatingManualURL = true
        manualURLError = nil
        defer { isValidatingManualURL = false }

        do {
            let info = try await serverInfoFetcher.fetch(from: parsed)
            selectedServer = SelectedServer(
                displayName: info.serverName ?? parsed.host ?? "Server",
                url: parsed,
                discoveredViaBonjour: false
            )
            await advanceToAuth()
        } catch let error as ServerInfoFetcher.ServerInfoError {
            manualURLError = error.errorDescription
        } catch {
            manualURLError = error.localizedDescription
        }
    }

    // MARK: - Auth phase entry

    /// Probes Quick Connect availability and routes to the appropriate auth
    /// phase. If the server has Quick Connect enabled, initiates the session
    /// and goes to `.quickConnect`. Otherwise falls back to `.password`.
    private func advanceToAuth() async {
        guard let selected = selectedServer else { return }
        let transport = quickConnectTransportFactory(selected.url)
        let isEnabled = await (try? transport.isEnabled(serverURL: selected.url)) ?? false
        if isEnabled {
            await beginQuickConnect(server: selected, transport: transport)
        } else {
            phase = .password(serverDisplay: selected.displayName)
            passwordError = nil
            passwordUsername = ""
            passwordPassword = ""
        }
    }

    func switchToQuickConnect() async {
        guard let selected = selectedServer else { return }
        let transport = quickConnectTransportFactory(selected.url)
        await beginQuickConnect(server: selected, transport: transport)
    }

    private func beginQuickConnect(server: SelectedServer, transport: any QuickConnectTransport) async {
        let session = QuickConnectSession(serverURL: server.url, transport: transport)
        quickConnectSession = session
        quickConnectError = nil
        quickConnectCode = nil
        quickConnectIsPolling = true
        phase = .quickConnect(serverDisplay: server.displayName)
        observeQuickConnect(session)
        TelemetryService.shared.recordOnboardingAuthMethod(.quickConnect)
        await session.start()
    }

    func switchToPassword() {
        quickConnectSession?.cancel()
        quickConnectSession = nil
        quickConnectStateObservation = nil
        quickConnectIsPolling = false
        guard let selected = selectedServer else { return }
        phase = .password(serverDisplay: selected.displayName)
    }

    func cancelQuickConnect() {
        quickConnectSession?.cancel()
        quickConnectSession = nil
        quickConnectStateObservation = nil
        quickConnectIsPolling = false
        phase = .welcome
    }

    func backToWelcome() {
        phase = .welcome
        manualURLError = nil
        passwordError = nil
        quickConnectError = nil
    }

    // MARK: - Password authentication

    func submitPassword() async {
        guard let selected = selectedServer else { return }
        guard !passwordUsername.isEmpty else {
            passwordError = "Please enter your username."
            return
        }

        isAuthenticating = true
        passwordError = nil
        defer { isAuthenticating = false }

        do {
            let result = try await passwordAuthenticator(
                selected.url,
                passwordUsername,
                passwordPassword
            )
            TelemetryService.shared.recordOnboardingAuthMethod(.password)
            await persistAndComplete(
                accessToken: result.response.accessToken,
                userID: result.response.user.id,
                deviceID: result.deviceID,
                selected: selected
            )
        } catch let error as JellyfinService.JellyfinError {
            switch error {
            case .invalidCredentials:
                passwordError = "Invalid username or password."
            default:
                passwordError = error.errorDescription
            }
        } catch {
            passwordError = error.localizedDescription
        }
    }

    // MARK: - Quick Connect observation

    private func observeQuickConnect(_ session: QuickConnectSession) {
        quickConnectStateObservation = session.$state.sink { [weak self] state in
            Task { @MainActor in
                self?.handleQuickConnect(state: state)
            }
        }
    }

    private func handleQuickConnect(state: QuickConnectSession.State) {
        switch state {
        case .idle:
            break
        case let .pending(code, _):
            quickConnectCode = code
            quickConnectError = nil
            quickConnectIsPolling = true
        case let .approved(authResponse):
            quickConnectIsPolling = false
            Task { await finishQuickConnectAuth(authResponse: authResponse) }
        case .expired:
            quickConnectIsPolling = false
            quickConnectError = "Code expired. Tap retry to request a new one."
        case let .failed(error):
            quickConnectIsPolling = false
            quickConnectError = error.errorDescription
        case .cancelled:
            quickConnectIsPolling = false
        }
    }

    private func finishQuickConnectAuth(authResponse: AuthResponse) async {
        guard let selected = selectedServer else { return }
        let service = JellyfinService(
            serverURL: selected.url,
            accessToken: authResponse.accessToken,
            userID: authResponse.user.id
        )
        let deviceID = await service.getDeviceID()
        await persistAndComplete(
            accessToken: authResponse.accessToken,
            userID: authResponse.user.id,
            deviceID: deviceID,
            selected: selected
        )
    }

    // MARK: - Completion

    private func persistAndComplete(
        accessToken: String,
        userID: String,
        deviceID: String,
        selected: SelectedServer
    ) async {
        phase = .completing

        let externalURL: URL
        let internalURL: URL?
        if selected.discoveredViaBonjour {
            // Bonjour-discovered URL is the LAN URL. We don't have a WAN URL
            // yet — caller can add one later.
            externalURL = selected.url
            internalURL = selected.url
        } else {
            // Manual entry — fetch /System/Info/Public to learn LAN URL.
            externalURL = selected.url
            internalURL = await fetchLocalAddress(from: selected.url)
        }

        let config = ServerConfiguration(
            name: selected.displayName,
            jellyfinURL: externalURL,
            jellyfinUserID: userID,
            lastUsed: Date(),
            createdAt: Date(),
            internalJellyfinURL: internalURL == externalURL ? nil : internalURL,
            internalNetworkSSIDs: []
        )
        appState.addServer(config)
        appState.saveJellyfinCredentials(
            serverID: config.id,
            accessToken: accessToken,
            userID: userID,
            deviceID: deviceID
        )
        appState.switchServer(to: config.id)
        onboardingManager.markOnboardingComplete()
        appState.isAuthenticated = true
        TelemetryService.shared.recordOnboardingCompleted()
    }

    private func fetchLocalAddress(from baseURL: URL) async -> URL? {
        do {
            let info = try await serverInfoFetcher.fetch(from: baseURL)
            guard let local = info.localAddress, local != baseURL else { return nil }
            return local
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func toViewSuggestion(_ suggestion: WelcomeSuggestion) -> WelcomeView.Suggestion {
        WelcomeView.Suggestion(
            id: suggestion.id,
            title: suggestion.title,
            subtitle: suggestion.subtitle,
            symbolName: suggestion.symbolName
        )
    }
}

private enum ClientIdentity {
    static var deviceID: String {
        if let stored = KeychainManager.shared.getString(for: .jellyfinDeviceID) {
            return stored
        }
        let new = UUID().uuidString
        KeychainManager.shared.save(new, for: .jellyfinDeviceID)
        return new
    }
}
