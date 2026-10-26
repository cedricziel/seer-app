@testable import SeerApp
import XCTest

final class RequestSeasonSelectionTests: XCTestCase {
    func testTVCannotSubmitWhileLoading() {
        let selection = RequestSeasonSelection()

        XCTAssertFalse(selection.canSubmit(isTV: true, isLoading: true, availableSeasons: []))
    }

    func testTVCannotSubmitRetainedSelectionDuringRetry() {
        var selection = RequestSeasonSelection()
        selection.update(availableSeasons: [1, 2])

        XCTAssertFalse(selection.canSubmit(isTV: true, isLoading: true, availableSeasons: [1, 2]))
    }

    func testTVRequiresASelectionFromAvailableSeasons() {
        var selection = RequestSeasonSelection()
        selection.selected = [9]

        XCTAssertFalse(selection.canSubmit(isTV: true, isLoading: false, availableSeasons: [1, 2]))
    }

    func testTVWithoutSeasonsCannotSubmitRetainedSelection() {
        var selection = RequestSeasonSelection()
        selection.selected = [1]

        XCTAssertFalse(selection.canSubmit(isTV: true, isLoading: false, availableSeasons: []))
    }

    func testTVWithOnlySpecialsCannotSubmit() {
        var selection = RequestSeasonSelection()
        selection.update(availableSeasons: [0])

        XCTAssertFalse(selection.canSubmit(isTV: true, isLoading: false, availableSeasons: [0]))
    }

    func testMovieCanSubmitWithoutTVDetails() {
        let selection = RequestSeasonSelection()

        XCTAssertTrue(selection.canSubmit(isTV: false, isLoading: true, availableSeasons: []))
    }

    func testLoadedTVDefaultsToAllSeasons() {
        var selection = RequestSeasonSelection()
        selection.update(availableSeasons: [])
        selection.update(availableSeasons: [2, 1])

        XCTAssertTrue(selection.canSubmit(isTV: true, isLoading: false, availableSeasons: [1, 2]))
        XCTAssertEqual(selection.seasonsToSubmit(availableSeasons: [1, 2]), [1, 2])
    }

    func testRetryPreservesSelectedSeasons() {
        var selection = RequestSeasonSelection()
        selection.update(availableSeasons: [1, 2])
        selection.selected = [2]
        selection.update(availableSeasons: [])
        selection.update(availableSeasons: [1, 2, 3])

        XCTAssertEqual(selection.seasonsToSubmit(availableSeasons: [1, 2, 3]), [2])
    }

    func testReloadDropsSeasonsThatAreNoLongerAvailable() {
        var selection = RequestSeasonSelection()
        selection.update(availableSeasons: [1, 2])
        selection.selected = [1]
        selection.update(availableSeasons: [2, 3])

        XCTAssertEqual(selection.selected, [])
        XCTAssertFalse(selection.canSubmit(isTV: true, isLoading: false, availableSeasons: [2, 3]))
    }

    func testRetryPreservesExplicitDeselection() {
        var selection = RequestSeasonSelection()
        selection.update(availableSeasons: [1, 2])
        selection.selected.removeAll()
        selection.update(availableSeasons: [])
        selection.update(availableSeasons: [1, 2])

        XCTAssertFalse(selection.canSubmit(isTV: true, isLoading: false, availableSeasons: [1, 2]))
    }

    func testSubmissionExcludesUnavailableAndSpecialSeasons() {
        var selection = RequestSeasonSelection()
        selection.selected = [0, 1, 2, 9]

        XCTAssertEqual(selection.seasonsToSubmit(availableSeasons: [0, 2, 1]), [1, 2])
    }
}
