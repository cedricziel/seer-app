@testable import SeerCore
import XCTest

final class StringExtensionsTests: XCTestCase {
    // MARK: - isBlank

    func testIsBlank_emptyString_returnsTrue() {
        XCTAssertTrue("".isBlank)
    }

    func testIsBlank_whitespaceOnly_returnsTrue() {
        XCTAssertTrue("   ".isBlank)
    }

    func testIsBlank_tabsAndNewlines_returnsTrue() {
        XCTAssertTrue("\t\n  \n".isBlank)
    }

    func testIsBlank_textWithSurroundingWhitespace_returnsFalse() {
        XCTAssertFalse("  hello  ".isBlank)
    }

    func testIsBlank_nonEmptyText_returnsFalse() {
        XCTAssertFalse("hello".isBlank)
    }

    // MARK: - nilIfBlank

    func testNilIfBlank_emptyString_returnsNil() {
        XCTAssertNil("".nilIfBlank)
    }

    func testNilIfBlank_whitespace_returnsNil() {
        XCTAssertNil("   ".nilIfBlank)
    }

    func testNilIfBlank_nonBlankString_returnsString() {
        XCTAssertEqual("hello".nilIfBlank, "hello")
    }

    func testNilIfBlank_preservesSurroundingWhitespace() {
        // The string is non-blank because it contains "hello"
        XCTAssertEqual("  hello  ".nilIfBlank, "  hello  ")
    }

    // MARK: - truncated

    func testTruncated_shorterThanLimit_returnsOriginal() {
        XCTAssertEqual("hi".truncated(to: 10), "hi")
    }

    func testTruncated_equalToLimit_returnsOriginal() {
        XCTAssertEqual("hello".truncated(to: 5), "hello")
    }

    func testTruncated_longerThanLimit_truncatesWithEllipsis() {
        XCTAssertEqual("hello world".truncated(to: 5), "hello...")
    }

    func testTruncated_customTrailing_usesProvidedTrailing() {
        XCTAssertEqual("hello world".truncated(to: 5, trailing: "→"), "hello→")
    }

    func testTruncated_emptyTrailing_truncatesWithoutSuffix() {
        XCTAssertEqual("hello world".truncated(to: 5, trailing: ""), "hello")
    }
}
