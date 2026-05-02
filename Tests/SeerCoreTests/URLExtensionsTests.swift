@testable import SeerCore
import XCTest

final class URLExtensionsTests: XCTestCase {
    let baseURL = URL(string: "https://example.com")!

    // MARK: - appendingPathComponents

    func testAppendingPathComponents_singleComponent_appendsCorrectly() {
        let url = baseURL.appendingPathComponents("api")
        XCTAssertEqual(url.absoluteString, "https://example.com/api")
    }

    func testAppendingPathComponents_multipleComponents_appendsInOrder() {
        let url = baseURL.appendingPathComponents("api", "v1", "items")
        XCTAssertEqual(url.absoluteString, "https://example.com/api/v1/items")
    }

    func testAppendingPathComponents_noComponents_returnsOriginal() {
        let url = baseURL.appendingPathComponents()
        XCTAssertEqual(url.absoluteString, baseURL.absoluteString)
    }

    func testAppendingPathComponents_preservesExistingPath() {
        let urlWithPath = URL(string: "https://example.com/base")!
        let url = urlWithPath.appendingPathComponents("api", "v1")
        XCTAssertEqual(url.absoluteString, "https://example.com/base/api/v1")
    }

    // MARK: - withQueryItems

    func testWithQueryItems_emptyDictionary_returnsURLWithNoItems() {
        let url = baseURL.withQueryItems([:])
        XCTAssertNotNil(url)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        XCTAssertTrue((components?.queryItems ?? []).isEmpty)
    }

    func testWithQueryItems_singleItem_appendsQuery() {
        let url = baseURL.withQueryItems(["foo": "bar"])
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.query, "foo=bar")
    }

    func testWithQueryItems_multipleItems_appendsAllItems() {
        // We can't rely on dictionary ordering, so we parse the resulting query
        let url = baseURL.withQueryItems(["a": "1", "b": "2"])
        XCTAssertNotNil(url)

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(URLQueryItem(name: "a", value: "1")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "b", value: "2")))
    }

    func testWithQueryItems_appendsToExistingQuery() {
        let urlWithQuery = URL(string: "https://example.com?existing=value")!
        let url = urlWithQuery.withQueryItems(["new": "param"])
        XCTAssertNotNil(url)

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(URLQueryItem(name: "existing", value: "value")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "new", value: "param")))
    }

    // MARK: - urlComponents

    func testURLComponents_validURL_returnsComponents() throws {
        let components = try baseURL.urlComponents()
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "example.com")
    }

    func testURLComponents_resolvingAgainstBaseURL_passesParameter() throws {
        let components = try baseURL.urlComponents(resolvingAgainstBaseURL: true)
        XCTAssertEqual(components.host, "example.com")
    }
}
