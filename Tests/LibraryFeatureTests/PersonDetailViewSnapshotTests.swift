import JellyfinClient
@testable import SeerApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for the presentational sub-views inside PersonDetailView.
/// PersonDetailView itself owns a JellyfinService (loaded via AppState) and
/// is hard to render deterministically. The header, biography, and
/// filmography sections are pure presentational structs that take plain
/// props, so we snapshot those directly.
@MainActor
final class PersonDetailViewSnapshotTests: XCTestCase {
    // MARK: - Header

    func testHeader_FullDetails_iPhoneCompact() {
        let view = PersonDetailHeader(
            name: "Jane Doe",
            role: "Lead Actor",
            headshotURL: nil,
            lifespan: PersonDetailHeader.lifespan(
                born: makeDate(1970, 4, 15),
                died: nil
            ),
            birthplace: "Los Angeles, California"
        )
        .padding()

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testHeader_NameOnly_iPhoneCompact() {
        let view = PersonDetailHeader(
            name: "Anonymous Stagehand",
            role: nil,
            headshotURL: nil,
            lifespan: nil,
            birthplace: nil
        )
        .padding()

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testHeader_DeceasedActor_iPhoneCompact() {
        let view = PersonDetailHeader(
            name: "Old-Time Star",
            role: "Director",
            headshotURL: nil,
            lifespan: PersonDetailHeader.lifespan(
                born: makeDate(1920, 1, 1),
                died: makeDate(1995, 6, 30)
            ),
            birthplace: "Brooklyn, New York"
        )
        .padding()

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    // MARK: - Biography

    func testBiography_ShortText_iPhoneCompact() {
        let view = PersonBiographyView(
            overview: "An award-winning actor known for leading roles in independent dramas."
        )
        .padding()

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    // MARK: - Filmography

    func testFilmography_Loading_iPhoneCompact() {
        let view = PersonFilmographyView(
            state: .loading,
            personName: "Jane Doe",
            imageURL: { _ in nil }
        )
        .padding()

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testFilmography_Empty_iPhoneCompact() {
        let view = PersonFilmographyView(
            state: .empty,
            personName: "Jane Doe",
            imageURL: { _ in nil }
        )
        .padding()

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testFilmography_Error_iPhoneCompact() {
        let view = PersonFilmographyView(
            state: .error("The Jellyfin server returned a 500."),
            personName: "Jane Doe",
            imageURL: { _ in nil }
        )
        .padding()

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    func testFilmography_Loaded_iPhoneCompact() {
        let items = (1 ... 5).map { index in
            makeMediaItem(id: "film-\(index)", name: "Test Film \(index)", year: 2000 + index)
        }
        let view = NavigationStack {
            PersonFilmographyView(
                state: .loaded(items),
                personName: "Jane Doe",
                imageURL: { _ in nil },
                roleLabel: { "Actor · \($0.year.map(String.init) ?? "")" }
            )
            .padding()
        }

        assertSnapshot(
            of: view,
            as: .image(precision: 0.99, perceptualPrecision: 0.97, layout: .device(config: .iPhone13))
        )
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    private func makeMediaItem(id: String, name: String, year: Int) -> MediaItem {
        MediaItem(id: id, name: name, year: year, type: .movie)
    }
}
