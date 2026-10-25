import Foundation
import JellyfinClient
import os
import SeerCore

@MainActor
final class PersonDetailViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.seer.app", category: "PersonDetailViewModel")

    @Published var person: PersonDetail?
    @Published var filmography: [MediaItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let personId: String
    private let fallbackName: String
    private let fallbackImageTag: String?
    private let jellyfinService: JellyfinService?
    private let serverURL: URL?
    private var loadTask: Task<Void, Never>?

    static let filmographyLimit = 20

    init(person: MediaItem.Person, appState: AppState) {
        personId = person.id ?? ""
        fallbackName = person.name ?? "Unknown"
        fallbackImageTag = person.imageTag

        guard let serverURL = appState.jellyfinServerURL,
              let accessToken = appState.jellyfinAccessToken,
              let userID = appState.jellyfinUserID
        else {
            jellyfinService = nil
            serverURL = nil
            return
        }

        self.serverURL = serverURL
        jellyfinService = JellyfinService(
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            deviceID: appState.jellyfinDeviceID
        )
    }

    var displayName: String {
        person?.name ?? fallbackName
    }

    func load() async {
        guard !personId.isEmpty else {
            errorMessage = "Person details unavailable for this entry."
            return
        }
        guard let service = jellyfinService else {
            errorMessage = "Not connected to Jellyfin"
            return
        }

        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        loadTask = Task {
            async let detail = service.getPerson(id: personId)
            async let films = service.getItems(personId: personId, limit: Self.filmographyLimit)

            do {
                let (loadedDetail, loadedFilms) = try await (detail, films)
                guard !Task.isCancelled else { return }
                person = loadedDetail
                filmography = loadedFilms
            } catch {
                guard !Task.isCancelled else { return }
                Self.logger.error("Failed to load person \(self.personId): \(error.localizedDescription)")
                if person == nil, filmography.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }

            isLoading = false
        }

        await loadTask?.value
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    // MARK: - Image URLs

    func headshotURL(maxWidth: Int? = 320) -> URL? {
        guard !personId.isEmpty, let serverURL else { return nil }
        let tag = person?.imageTag ?? fallbackImageTag
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(personId)/Images/Primary"),
            resolvingAgainstBaseURL: false
        )
        var queryItems: [URLQueryItem] = []
        if let tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if let maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: String(maxWidth)))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    func imageURL(for item: MediaItem) -> URL? {
        serverURL?.appendingPathComponent("Items/\(item.id)/Images/Primary")
    }

    // MARK: - Filmography role/year label

    /// This person's role or type on the given filmography item (e.g.
    /// "Director" or a character name), recovered by matching `personId`
    /// against the item's `people` array.
    private func roleText(for item: MediaItem) -> String? {
        guard let match = item.people?.first(where: { $0.id == personId }) else { return nil }
        if let role = match.role, !role.isEmpty {
            return role
        }
        if let type = match.type, !type.isEmpty {
            return type
        }
        return nil
    }

    /// "Role · Year" when a role or type string can be recovered for this
    /// person on the item, else just the year, matching prior behavior.
    func roleLabel(for item: MediaItem) -> String? {
        switch (roleText(for: item), item.year) {
        case let (role?, year?):
            "\(role) · \(year)"
        case let (role?, nil):
            role
        case let (nil, year?):
            String(year)
        case (nil, nil):
            nil
        }
    }
}
