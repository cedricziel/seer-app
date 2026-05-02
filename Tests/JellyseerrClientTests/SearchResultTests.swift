@testable import JellyseerrClient
import XCTest

final class SearchResultTests: XCTestCase {
    // MARK: - displayTitle

    func testDisplayTitle_prefersTitle() {
        let result = makeResult(title: "Movie", name: "Show", originalTitle: "Original")
        XCTAssertEqual(result.displayTitle, "Movie")
    }

    func testDisplayTitle_fallsBackToName() {
        let result = makeResult(title: nil, name: "Show", originalTitle: "Original")
        XCTAssertEqual(result.displayTitle, "Show")
    }

    func testDisplayTitle_fallsBackToOriginalTitle() {
        let result = makeResult(title: nil, name: nil, originalTitle: "Original")
        XCTAssertEqual(result.displayTitle, "Original")
    }

    func testDisplayTitle_fallsBackToOriginalName() {
        let result = makeResult(title: nil, name: nil, originalTitle: nil, originalName: "OG Name")
        XCTAssertEqual(result.displayTitle, "OG Name")
    }

    func testDisplayTitle_allNil_returnsUnknown() {
        let result = makeResult(title: nil, name: nil, originalTitle: nil, originalName: nil)
        XCTAssertEqual(result.displayTitle, "Unknown")
    }

    // MARK: - displayYear

    func testDisplayYear_fromReleaseDate_returnsYear() {
        let result = makeResult(releaseDate: "2023-05-15")
        XCTAssertEqual(result.displayYear, "2023")
    }

    func testDisplayYear_fromFirstAirDate_whenNoReleaseDate() {
        let result = makeResult(releaseDate: nil, firstAirDate: "2021-03-10")
        XCTAssertEqual(result.displayYear, "2021")
    }

    func testDisplayYear_releaseDatePreferredOverFirstAirDate() {
        let result = makeResult(releaseDate: "2024-01-01", firstAirDate: "2020-01-01")
        XCTAssertEqual(result.displayYear, "2024")
    }

    func testDisplayYear_emptyDates_returnsNil() {
        let result = makeResult(releaseDate: "", firstAirDate: "")
        XCTAssertNil(result.displayYear)
    }

    func testDisplayYear_shortDateString_returnsNil() {
        let result = makeResult(releaseDate: "abc")
        XCTAssertNil(result.displayYear)
    }

    func testDisplayYear_allNil_returnsNil() {
        XCTAssertNil(makeResult(releaseDate: nil, firstAirDate: nil).displayYear)
    }

    // MARK: - posterURL / backdropURL

    func testPosterURL_withPath_buildsTMDBURL() {
        let result = makeResult(posterPath: "/abc.jpg")
        XCTAssertEqual(result.posterURL()?.absoluteString, "https://image.tmdb.org/t/p/w500/abc.jpg")
    }

    func testPosterURL_customSize() {
        let result = makeResult(posterPath: "/abc.jpg")
        XCTAssertEqual(
            result.posterURL(size: "original")?.absoluteString,
            "https://image.tmdb.org/t/p/original/abc.jpg"
        )
    }

    func testPosterURL_nilPath_returnsNil() {
        let result = makeResult(posterPath: nil)
        XCTAssertNil(result.posterURL())
    }

    func testBackdropURL_withPath_buildsTMDBURL() {
        let result = makeResult(backdropPath: "/back.jpg")
        XCTAssertEqual(result.backdropURL()?.absoluteString, "https://image.tmdb.org/t/p/w1280/back.jpg")
    }

    func testBackdropURL_nilPath_returnsNil() {
        XCTAssertNil(makeResult(backdropPath: nil).backdropURL())
    }

    // MARK: - isAvailable / hasPendingRequest

    func testIsAvailable_availableStatus_returnsTrue() {
        let result = makeResult(mediaInfoStatus: .available)
        XCTAssertTrue(result.isAvailable)
    }

    func testIsAvailable_otherStatus_returnsFalse() {
        let result = makeResult(mediaInfoStatus: .pending)
        XCTAssertFalse(result.isAvailable)
    }

    func testIsAvailable_noMediaInfo_returnsFalse() {
        let result = makeResult(mediaInfoStatus: nil)
        XCTAssertFalse(result.isAvailable)
    }

    func testHasPendingRequest_pendingStatus_returnsTrue() {
        XCTAssertTrue(makeResult(mediaInfoStatus: .pending).hasPendingRequest)
    }

    func testHasPendingRequest_processingStatus_returnsTrue() {
        XCTAssertTrue(makeResult(mediaInfoStatus: .processing).hasPendingRequest)
    }

    func testHasPendingRequest_availableStatus_returnsFalse() {
        XCTAssertFalse(makeResult(mediaInfoStatus: .available).hasPendingRequest)
    }

    func testHasPendingRequest_noMediaInfo_returnsFalse() {
        XCTAssertFalse(makeResult(mediaInfoStatus: nil).hasPendingRequest)
    }

    // MARK: - MediaType decoding

    func testDecode_movieMediaType() throws {
        let json = """
        {"id": 1, "mediaType": "movie", "title": "X"}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(SearchResult.self, from: json)
        XCTAssertEqual(result.mediaType, .movie)
    }

    func testDecode_tvShowMediaType() throws {
        let json = """
        {"id": 1, "mediaType": "tv", "name": "X"}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(SearchResult.self, from: json)
        XCTAssertEqual(result.mediaType, .tvShow)
    }

    // MARK: - Helpers

    private func makeResult(
        title: String? = nil,
        name: String? = nil,
        originalTitle: String? = nil,
        originalName: String? = nil,
        releaseDate: String? = nil,
        firstAirDate: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        mediaInfoStatus: SearchResult.MediaInfo.MediaStatus? = nil
    ) -> SearchResult {
        let mediaInfo = mediaInfoStatus.map {
            SearchResult.MediaInfo(id: 1, tmdbId: nil, tvdbId: nil, status: $0, requests: nil)
        }
        return SearchResult(
            id: 1,
            mediaType: .movie,
            title: title,
            name: name,
            originalTitle: originalTitle,
            originalName: originalName,
            overview: nil,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            firstAirDate: firstAirDate,
            voteAverage: nil,
            voteCount: nil,
            popularity: nil,
            originalLanguage: nil,
            genreIds: nil,
            mediaInfo: mediaInfo
        )
    }
}
