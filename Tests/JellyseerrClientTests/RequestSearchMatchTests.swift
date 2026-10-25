import JellyseerrClient
import XCTest

final class RequestSearchMatchTests: XCTestCase {
    func testExplicitTypeDoesNotFallBackToOtherType() throws {
        let results = try decode("[{\"id\":1,\"mediaType\":\"movie\",\"title\":\"Same title\"}]")
        XCTAssertNil(SearchResult.requestMatch(in: results, mediaType: .tvShow))
    }

    func testExplicitTypeSelectsMatchingResult() throws {
        let results = try decode("[{\"id\":1,\"mediaType\":\"movie\"},{\"id\":2,\"mediaType\":\"tv\"}]")
        XCTAssertEqual(SearchResult.requestMatch(in: results, mediaType: .tvShow)?.id, 2)
    }

    func testUnspecifiedTypeSkipsPeople() throws {
        let results = try decode("[{\"id\":1,\"mediaType\":\"person\"},{\"id\":2,\"mediaType\":\"movie\"}]")
        XCTAssertEqual(SearchResult.requestMatch(in: results, mediaType: nil)?.id, 2)
    }

    private func decode(_ json: String) throws -> [SearchResult] {
        try JSONDecoder().decode([SearchResult].self, from: Data(json.utf8))
    }
}
