@testable import JellyseerrClient
import XCTest

final class MediaRequestTests: XCTestCase {
    // MARK: - RequestStatus displayName / iconName

    func testRequestStatus_pending_hasCorrectDisplayAndIcon() {
        XCTAssertEqual(MediaRequest.RequestStatus.pending.displayName, "Pending")
        XCTAssertEqual(MediaRequest.RequestStatus.pending.iconName, "clock")
    }

    func testRequestStatus_approved_hasCorrectDisplayAndIcon() {
        XCTAssertEqual(MediaRequest.RequestStatus.approved.displayName, "Approved")
        XCTAssertEqual(MediaRequest.RequestStatus.approved.iconName, "checkmark.circle")
    }

    func testRequestStatus_declined_hasCorrectDisplayAndIcon() {
        XCTAssertEqual(MediaRequest.RequestStatus.declined.displayName, "Declined")
        XCTAssertEqual(MediaRequest.RequestStatus.declined.iconName, "xmark.circle")
    }

    func testRequestStatus_available_hasCorrectDisplayAndIcon() {
        XCTAssertEqual(MediaRequest.RequestStatus.available.displayName, "Available")
        XCTAssertEqual(MediaRequest.RequestStatus.available.iconName, "checkmark.seal.fill")
    }

    func testRequestStatus_processing_hasCorrectDisplayAndIcon() {
        XCTAssertEqual(MediaRequest.RequestStatus.processing.displayName, "Processing")
        XCTAssertEqual(MediaRequest.RequestStatus.processing.iconName, "arrow.triangle.2.circlepath")
    }

    func testRequestStatus_rawValueRoundTrip() {
        XCTAssertEqual(MediaRequest.RequestStatus(rawValue: 1), .pending)
        XCTAssertEqual(MediaRequest.RequestStatus(rawValue: 2), .approved)
        XCTAssertEqual(MediaRequest.RequestStatus(rawValue: 3), .declined)
        XCTAssertEqual(MediaRequest.RequestStatus(rawValue: 4), .available)
        XCTAssertEqual(MediaRequest.RequestStatus(rawValue: 5), .processing)
        XCTAssertNil(MediaRequest.RequestStatus(rawValue: 99))
    }

    // MARK: - MediaAvailabilityStatus

    func testMediaAvailabilityStatus_displayNames() {
        XCTAssertEqual(MediaRequest.MediaAvailabilityStatus.unknown.displayName, "Unknown")
        XCTAssertEqual(MediaRequest.MediaAvailabilityStatus.pending.displayName, "Pending")
        XCTAssertEqual(MediaRequest.MediaAvailabilityStatus.processing.displayName, "Downloading")
        XCTAssertEqual(MediaRequest.MediaAvailabilityStatus.partiallyAvailable.displayName, "Partially Available")
        XCTAssertEqual(MediaRequest.MediaAvailabilityStatus.available.displayName, "Available")
        XCTAssertEqual(MediaRequest.MediaAvailabilityStatus.deleted.displayName, "Deleted")
    }

    func testMediaAvailabilityStatus_iconNames_areUnique() {
        let icons: [String] = [
            MediaRequest.MediaAvailabilityStatus.unknown.iconName,
            MediaRequest.MediaAvailabilityStatus.pending.iconName,
            MediaRequest.MediaAvailabilityStatus.processing.iconName,
            MediaRequest.MediaAvailabilityStatus.partiallyAvailable.iconName,
            MediaRequest.MediaAvailabilityStatus.available.iconName,
            MediaRequest.MediaAvailabilityStatus.deleted.iconName
        ]
        XCTAssertEqual(Set(icons).count, icons.count, "Icon names should be unique per status")
    }

    // MARK: - MediaDetails

    func testMediaDetails_displayMediaType_movie() throws {
        let details = try makeMediaDetails(mediaType: "movie")
        XCTAssertEqual(details.displayMediaType, "Movie")
    }

    func testMediaDetails_displayMediaType_tv() throws {
        let details = try makeMediaDetails(mediaType: "tv")
        XCTAssertEqual(details.displayMediaType, "TV Show")
    }

    func testMediaDetails_displayMediaType_unknown_passesThrough() throws {
        let details = try makeMediaDetails(mediaType: "documentary")
        XCTAssertEqual(details.displayMediaType, "documentary")
    }

    func testMediaDetails_displayMediaType_nil_returnsUnknown() throws {
        let details = try makeMediaDetails(mediaType: nil)
        XCTAssertEqual(details.displayMediaType, "Unknown")
    }

    func testMediaDetails_displayTitle_prefersTitle() throws {
        let details = try makeMediaDetails(title: "The Movie", name: "Show", originalTitle: "OG")
        XCTAssertEqual(details.displayTitle, "The Movie")
    }

    func testMediaDetails_displayTitle_fallsBackToName() throws {
        let details = try makeMediaDetails(title: nil, name: "Show", originalTitle: "OG")
        XCTAssertEqual(details.displayTitle, "Show")
    }

    func testMediaDetails_displayTitle_fallsBackToOriginalTitle() throws {
        let details = try makeMediaDetails(title: nil, name: nil, originalTitle: "OG")
        XCTAssertEqual(details.displayTitle, "OG")
    }

    func testMediaDetails_displayTitle_allNil_returnsNil() throws {
        let details = try makeMediaDetails(title: nil, name: nil, originalTitle: nil)
        XCTAssertNil(details.displayTitle)
    }

    func testMediaDetails_availabilityStatus_resolvesFromInt() throws {
        let details = try makeMediaDetails(status: 5)
        XCTAssertEqual(details.availabilityStatus, .available)
    }

    func testMediaDetails_availabilityStatus_invalidValue_returnsUnknown() throws {
        let details = try makeMediaDetails(status: 99)
        XCTAssertEqual(details.availabilityStatus, .unknown)
    }

    func testMediaDetails_availabilityStatus_nilStatus_returnsUnknown() throws {
        let details = try makeMediaDetails(status: nil)
        XCTAssertEqual(details.availabilityStatus, .unknown)
    }

    // MARK: - User displayName

    func testUser_displayName_prefersJellyfin() throws {
        let user = try makeUser(jellyfinUsername: "jelly", plexUsername: "plex", username: "u", email: "e@x")
        XCTAssertEqual(user.displayName, "jelly")
    }

    func testUser_displayName_fallsBackToPlex() throws {
        let user = try makeUser(jellyfinUsername: nil, plexUsername: "plex", username: "u", email: "e@x")
        XCTAssertEqual(user.displayName, "plex")
    }

    func testUser_displayName_fallsBackToUsername() throws {
        let user = try makeUser(jellyfinUsername: nil, plexUsername: nil, username: "u", email: "e@x")
        XCTAssertEqual(user.displayName, "u")
    }

    func testUser_displayName_fallsBackToEmail() throws {
        let user = try makeUser(jellyfinUsername: nil, plexUsername: nil, username: nil, email: "e@x")
        XCTAssertEqual(user.displayName, "e@x")
    }

    func testUser_displayName_allNil_returnsUnknownUser() throws {
        let user = try makeUser(jellyfinUsername: nil, plexUsername: nil, username: nil, email: nil)
        XCTAssertEqual(user.displayName, "Unknown User")
    }

    // MARK: - formattedCreatedAt

    func testFormattedCreatedAt_invalidDate_returnsRawString() throws {
        let request = try makeRequest(createdAt: "not-a-date")
        XCTAssertEqual(request.formattedCreatedAt, "not-a-date")
    }

    // MARK: - Helpers

    private func makeMediaDetails(
        id: Int = 1,
        tmdbId: Int? = nil,
        tvdbId: Int? = nil,
        status: Int? = nil,
        mediaType: String? = nil,
        title: String? = nil,
        name: String? = nil,
        originalTitle: String? = nil
    ) throws -> MediaRequest.MediaDetails {
        let json = """
        {
          "id": \(id),
          "tmdbId": \(tmdbId.map(String.init) ?? "null"),
          "tvdbId": \(tvdbId.map(String.init) ?? "null"),
          "status": \(status.map(String.init) ?? "null"),
          "mediaType": \(mediaType.map { "\"\($0)\"" } ?? "null"),
          "externalServiceId": null,
          "externalServiceSlug": null,
          "title": \(title.map { "\"\($0)\"" } ?? "null"),
          "name": \(name.map { "\"\($0)\"" } ?? "null"),
          "originalTitle": \(originalTitle.map { "\"\($0)\"" } ?? "null"),
          "posterPath": null
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(MediaRequest.MediaDetails.self, from: json)
    }

    private func makeUser(
        id: Int = 1,
        jellyfinUsername: String? = nil,
        plexUsername: String? = nil,
        username: String? = nil,
        email: String? = nil
    ) throws -> MediaRequest.User {
        let json = """
        {
          "id": \(id),
          "email": \(email.map { "\"\($0)\"" } ?? "null"),
          "username": \(username.map { "\"\($0)\"" } ?? "null"),
          "plexToken": null,
          "plexUsername": \(plexUsername.map { "\"\($0)\"" } ?? "null"),
          "jellyfinUsername": \(jellyfinUsername.map { "\"\($0)\"" } ?? "null"),
          "avatar": null,
          "permissions": null,
          "userType": null,
          "createdAt": null,
          "updatedAt": null,
          "requestCount": null
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(MediaRequest.User.self, from: json)
    }

    private func makeRequest(createdAt: String) throws -> MediaRequest {
        let json = """
        {
          "id": 1,
          "status": 1,
          "createdAt": "\(createdAt)",
          "updatedAt": "\(createdAt)",
          "type": "movie",
          "is4k": false,
          "serverId": null,
          "profileId": null,
          "rootFolder": null,
          "languageProfileId": null,
          "tags": null,
          "media": {
            "id": 1, "tmdbId": null, "tvdbId": null, "status": null, "mediaType": "movie",
            "externalServiceId": null, "externalServiceSlug": null,
            "title": "X", "name": null, "originalTitle": null, "posterPath": null
          },
          "requestedBy": {
            "id": 1, "email": null, "username": "u", "plexToken": null, "plexUsername": null,
            "jellyfinUsername": null, "avatar": null, "permissions": null, "userType": null,
            "createdAt": null, "updatedAt": null, "requestCount": null
          },
          "modifiedBy": null,
          "seasons": null
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(MediaRequest.self, from: json)
    }
}
