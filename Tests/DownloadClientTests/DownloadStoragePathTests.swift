@testable import DownloadClient
import Foundation
import XCTest

final class DownloadStoragePathTests: XCTestCase {
    func testPermanentDownloadsUseSupportedPlatformDirectory() {
        #if os(tvOS)
            XCTAssertEqual(DownloadStorage.defaultSearchPathDirectory, .cachesDirectory)
        #else
            XCTAssertEqual(DownloadStorage.defaultSearchPathDirectory, .documentDirectory)
        #endif
    }

    func testPlaybackFileURLMatchesStorageDirectory() throws {
        let download = Download(
            serverID: "server", itemID: "movie", mediaSourceID: "source", name: "Movie", mediaType: "Movie"
        )
        download.state = .completed
        download.relativePath = "server/Movie/movie/movie.mp4"
        let base = try XCTUnwrap(FileManager.default.urls(
            for: DownloadStorage.defaultSearchPathDirectory, in: .userDomainMask
        ).first)

        XCTAssertEqual(
            download.fileURL,
            base.appendingPathComponent("Downloads").appendingPathComponent("server/Movie/movie/movie.mp4")
        )
    }

    func testPendingDownloadsUseSupportedPlatformDirectory() throws {
        #if os(tvOS)
            let expected: FileManager.SearchPathDirectory = .cachesDirectory
        #else
            let expected: FileManager.SearchPathDirectory = .applicationSupportDirectory
        #endif
        let base = try XCTUnwrap(FileManager.default.urls(for: expected, in: .userDomainMask).first)

        XCTAssertEqual(BackgroundSessionManager.pendingSearchPathDirectory, expected)
        XCTAssertEqual(
            BackgroundSessionManager.pendingDirectory,
            base.appendingPathComponent("PendingDownloads", isDirectory: true)
        )
    }
}
