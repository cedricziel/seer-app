@testable import SeerCore
import XCTest

final class URLExtensionsTests: XCTestCase {
    private func makeBaseURL() throws -> URL {
        try XCTUnwrap(URL(string: "https://example.com"))
    }

    // MARK: - appendingPathComponents

    func testAppendingPathComponents_singleComponent_appendsCorrectly() throws {
        let url = try makeBaseURL().appendingPathComponents("api")
        XCTAssertEqual(url.absoluteString, "https://example.com/api")
    }

    func testAppendingPathComponents_multipleComponents_appendsInOrder() throws {
        let url = try makeBaseURL().appendingPathComponents("api", "v1", "items")
        XCTAssertEqual(url.absoluteString, "https://example.com/api/v1/items")
    }

    func testAppendingPathComponents_noComponents_returnsOriginal() throws {
        let baseURL = try makeBaseURL()
        let url = baseURL.appendingPathComponents()
        XCTAssertEqual(url.absoluteString, baseURL.absoluteString)
    }

    func testAppendingPathComponents_preservesExistingPath() throws {
        let urlWithPath = try XCTUnwrap(URL(string: "https://example.com/base"))
        let url = urlWithPath.appendingPathComponents("api", "v1")
        XCTAssertEqual(url.absoluteString, "https://example.com/base/api/v1")
    }

    // MARK: - withQueryItems

    func testWithQueryItems_emptyDictionary_returnsURLWithNoItems() throws {
        let url = try XCTUnwrap(makeBaseURL().withQueryItems([:]))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertTrue((components?.queryItems ?? []).isEmpty)
    }

    func testWithQueryItems_singleItem_appendsQuery() throws {
        let url = try XCTUnwrap(makeBaseURL().withQueryItems(["foo": "bar"]))
        XCTAssertEqual(url.query, "foo=bar")
    }

    func testWithQueryItems_multipleItems_appendsAllItems() throws {
        // We can't rely on dictionary ordering, so we parse the resulting query
        let url = try XCTUnwrap(makeBaseURL().withQueryItems(["a": "1", "b": "2"]))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(URLQueryItem(name: "a", value: "1")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "b", value: "2")))
    }

    func testWithQueryItems_appendsToExistingQuery() throws {
        let urlWithQuery = try XCTUnwrap(URL(string: "https://example.com?existing=value"))
        let url = try XCTUnwrap(urlWithQuery.withQueryItems(["new": "param"]))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(URLQueryItem(name: "existing", value: "value")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "new", value: "param")))
    }

    // MARK: - urlComponents

    func testURLComponents_validURL_returnsComponents() throws {
        let components = try makeBaseURL().urlComponents()
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "example.com")
    }

    func testURLComponents_resolvingAgainstBaseURL_passesParameter() throws {
        let components = try makeBaseURL().urlComponents(resolvingAgainstBaseURL: true)
        XCTAssertEqual(components.host, "example.com")
    }
}
