@testable import DownloadClient
import XCTest

final class DownloadQualityTests: XCTestCase {
    // MARK: - displayName

    func testDisplayName_original() {
        XCTAssertEqual(DownloadQuality.original.displayName, "Original")
    }

    func testDisplayName_high() {
        XCTAssertEqual(DownloadQuality.high.displayName, "High (1080p)")
    }

    func testDisplayName_medium() {
        XCTAssertEqual(DownloadQuality.medium.displayName, "Medium (720p)")
    }

    func testDisplayName_low() {
        XCTAssertEqual(DownloadQuality.low.displayName, "Low (480p)")
    }

    // MARK: - maxBitrate

    func testMaxBitrate_original_isUnlimited() {
        XCTAssertEqual(DownloadQuality.original.maxBitrate, 0)
    }

    func testMaxBitrate_high_is8Mbps() {
        XCTAssertEqual(DownloadQuality.high.maxBitrate, 8_000_000)
    }

    func testMaxBitrate_medium_is4Mbps() {
        XCTAssertEqual(DownloadQuality.medium.maxBitrate, 4_000_000)
    }

    func testMaxBitrate_low_is1500Kbps() {
        XCTAssertEqual(DownloadQuality.low.maxBitrate, 1_500_000)
    }

    func testMaxBitrate_decreasesAcrossQualityTiers() {
        XCTAssertGreaterThan(DownloadQuality.high.maxBitrate, DownloadQuality.medium.maxBitrate)
        XCTAssertGreaterThan(DownloadQuality.medium.maxBitrate, DownloadQuality.low.maxBitrate)
    }

    // MARK: - maxWidth

    func testMaxWidth_original_isNil() {
        XCTAssertNil(DownloadQuality.original.maxWidth)
    }

    func testMaxWidth_high_is1920() {
        XCTAssertEqual(DownloadQuality.high.maxWidth, 1920)
    }

    func testMaxWidth_medium_is1280() {
        XCTAssertEqual(DownloadQuality.medium.maxWidth, 1280)
    }

    func testMaxWidth_low_is854() {
        XCTAssertEqual(DownloadQuality.low.maxWidth, 854)
    }

    // MARK: - estimatedSizePerHourMB

    func testEstimatedSize_decreasesWithQuality() {
        XCTAssertGreaterThan(
            DownloadQuality.high.estimatedSizePerHourMB,
            DownloadQuality.medium.estimatedSizePerHourMB
        )
        XCTAssertGreaterThan(
            DownloadQuality.medium.estimatedSizePerHourMB,
            DownloadQuality.low.estimatedSizePerHourMB
        )
    }

    func testEstimatedSize_allValuesPositive() {
        for quality in DownloadQuality.allCases {
            XCTAssertGreaterThan(quality.estimatedSizePerHourMB, 0, "\(quality) should have positive size estimate")
        }
    }

    // MARK: - Encoding / Codable

    func testEncodingRoundTrip() throws {
        for quality in DownloadQuality.allCases {
            let data = try JSONEncoder().encode(quality)
            let decoded = try JSONDecoder().decode(DownloadQuality.self, from: data)
            XCTAssertEqual(decoded, quality)
        }
    }

    // MARK: - allCases

    func testAllCases_includesAllQualities() {
        XCTAssertEqual(DownloadQuality.allCases.count, 4)
        XCTAssertTrue(DownloadQuality.allCases.contains(.original))
        XCTAssertTrue(DownloadQuality.allCases.contains(.high))
        XCTAssertTrue(DownloadQuality.allCases.contains(.medium))
        XCTAssertTrue(DownloadQuality.allCases.contains(.low))
    }
}
