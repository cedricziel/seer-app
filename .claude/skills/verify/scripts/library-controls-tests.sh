#!/bin/sh
set -eu
# Usage: library-controls-tests.sh SIMULATOR_RUNTIME_IDENTIFIER EVIDENCE_DIRECTORY [before|after] [recovery]
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
runtime=${1:?Pass an available iOS simulator runtime identifier}
evidence=${2:?Pass an absolute evidence directory outside the checkout}
mode=${3:-after}
case "$mode" in before|after) ;; *) echo "Unknown mode: $mode" >&2; exit 1 ;; esac
filter=${4:-}
set --
if [ "$filter" = recovery ]; then
 set -- -only-testing:ControlsTests/ControlsTests/testRetryPreservesLibraryFiltersAndSort \
  -only-testing:ControlsTests/ControlsTests/testRetryPreservesRecentFiltersAndSort
elif [ -n "$filter" ]; then
 echo "Unknown filter: $filter" >&2; exit 1
fi
case "$evidence" in /*) ;; *) exit 1 ;; esac
case "$evidence" in "$repo"|"$repo"/*) exit 1 ;; esac
work=$(mktemp -d /private/tmp/library-controls.XXXXXX)
sim=
cleanup() {
 if [ -n "$sim" ]; then xcrun simctl shutdown "$sim" >/dev/null 2>&1 || true; xcrun simctl delete "$sim" >/dev/null 2>&1 || true; fi
 rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/App" "$work/Client" "$work/Core" "$work/Offline" "$work/UI" "$work/Playback" "$work/Tests" "$evidence"
for path in Features/Library/LibraryGridView.swift Features/Library/MediaDetailView+SeriesSection.swift; do
 if [ "$mode" = before ]; then git -C "$repo" show "origin/main:$path" > "$work/App/$(basename "$path")"; else cp "$repo/$path" "$work/App/"; fi
done
cp "$repo/Packages/SeerUI/Sources/SeerUI/LoadingView.swift" "$repo/Packages/SeerUI/Sources/SeerUI/SectionEmptyView.swift" "$work/UI/"
cat > "$work/Client/Models.swift" <<'SWIFT'
import Foundation
public struct Library: Hashable { public let name = "Test Library"; public init() {} }
public struct MediaItem: Identifiable, Hashable {
 public let id: String
 public let name: String
 public let type = Kind.series
 public let year: Int? = nil
 public let userData: UserData? = nil
 public let isPlayable = false
 public init(id: String, name: String) { self.id = id; self.name = name }
 public enum Kind { case movie, series }
 public struct UserData: Hashable { public let played: Bool; public let playbackPositionTicks: Int64 }
}
SWIFT
cat > "$work/Core/State.swift" <<'SWIFT'
import Combine
public final class AppState: ObservableObject { public init() {} }
SWIFT
cat > "$work/Offline/Network.swift" <<'SWIFT'
import Combine
public final class NetworkMonitor: ObservableObject { public init() {} }
SWIFT
echo 'import Foundation' > "$work/Playback/Placeholder.swift"
cat > "$work/App/Fixtures.swift" <<'SWIFT'
import JellyfinClient
import OfflineSync
import SeerCore
import SwiftData
import SwiftUI

@MainActor final class LibraryViewModel: ObservableObject {
 enum WatchStatusFilter: String, CaseIterable { case all = "All", unwatched = "Unwatched", favorites = "Favorites" }
 enum MediaTypeFilter: String, CaseIterable { case all = "All", movies = "Movies", series = "Series" }
 enum SortOption: String, CaseIterable { case name = "Name", dateAdded = "Date Added" }
 @Published var watchStatusFilter = WatchStatusFilter.all
 @Published var selectedMediaType = MediaTypeFilter.all
 @Published var sortOption = SortOption.name
 @Published var mediaItems: [MediaItem] = []
 @Published var errorMessage: String?
 let totalItemCount: Int? = nil
 let isOffline = false
 let isLoading = false
 let isLoadingMore = false
 private var attempts = 0
 init(appState: AppState) {}
 func enterDestination(_ destination: LibraryGridDestination, modelContext: ModelContext, networkMonitor: NetworkMonitor) async {
  watchStatusFilter = .all; selectedMediaType = .all; errorMessage = "Test connection failed"
 }
 func filterChanged() async {
  attempts += 1
  if ProcessInfo.processInfo.arguments.contains("recover"), attempts >= 3 {
   mediaItems = [MediaItem(id: "result", name: "Recovered \(watchStatusFilter.rawValue) \(selectedMediaType.rawValue) \(sortOption.rawValue)")]
   errorMessage = nil
  } else { errorMessage = "Test connection failed" }
 }
 func loadMoreItemsIfNeeded(currentItem: MediaItem) async {}
 func imageURL(for item: MediaItem) -> URL? { nil }
 func markAsWatched(_ item: MediaItem, watched: Bool) async throws {}
}
struct MediaContextMenuConfig {
 let canPlay: Bool; let canDownload: Bool; let isDownloaded: Bool; let isWatched: Bool; let showDetailsOption: Bool
}
struct MediaContextMenuActions { let onPlay: (() -> Void)?; let onToggleWatched: (Bool) -> Void }
struct MediaCard: View {
 let title: String; let subtitle: String?; let imageURL: URL?
 let contextMenuConfig: MediaContextMenuConfig; let contextMenuActions: MediaContextMenuActions
 var body: some View { Text(title) }
}
func mediaGridColumns(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] { [GridItem(.flexible())] }
struct VideoPlayerView: View {
 let item: MediaItem; let appState: AppState; let startPositionTicks: Int64; let onPiPStart: () -> Void
 var body: some View { EmptyView() }
}
extension View {
 func playerCover<Content: View>(item: Binding<MediaItem?>, @ViewBuilder content: (MediaItem) -> Content) -> some View { self }
}
@MainActor final class SeriesDetailViewModel: ObservableObject {
 let seasons = [MediaItem(id: "one", name: "Season 1"), MediaItem(id: "two", name: "Season 2")]
 @Published var selectedSeasonID: String? = "one"
 let isLoadingSeasons = false
 let isLoadingEpisodes: [String: Bool] = [:]
 let episodesBySeason: [String: [MediaItem]] = [:]
 func selectSeason(_ id: String) async { selectedSeasonID = id }
 enum ImageType { case primary }
 func imageURL(for item: MediaItem, type: ImageType) -> URL? { nil }
}
struct MediaDetailView: View {
 @StateObject var model = SeriesDetailViewModel()
 var seriesViewModel: SeriesDetailViewModel? { model }
 @State var selectedEpisodeForPlayback: MediaItem?
 @State var selectedEpisodeForDetail: MediaItem?
 @State var showPlayer = false
 @State var showEpisodeDetail = false
 var body: some View { seasonsSection.padding() }
 func downloadSeason(episodes: [MediaItem]) async {}
 func downloadEpisode(_ episode: MediaItem) async {}
 func cancelEpisodeDownload(_ episode: MediaItem) async {}
 func downloadStateFor(episodeID: String) -> Bool { false }
}
struct EpisodeRow: View {
 let episode: MediaItem; let imageURL: URL?; let onPlay: () -> Void; let onTap: () -> Void
 let onDownload: () async -> Void; let onCancelDownload: () async -> Void; let downloadState: Bool
 var body: some View { Text(episode.name) }
}
@Model final class FixtureRecord { var name = ""; init() {} }
@main struct Harness: App {
 @StateObject var state = AppState()
 @StateObject var network = NetworkMonitor()
 var body: some Scene {
  WindowGroup {
   NavigationStack {
    if ProcessInfo.processInfo.arguments.contains("seasons") { MediaDetailView() }
    else {
     LibraryGridView(destination: ProcessInfo.processInfo.arguments.contains("recent") ? .recentlyAdded : .library(Library()), appState: state)
    }
   }.environmentObject(network).modelContainer(for: FixtureRecord.self, inMemory: true)
  }
 }
}
SWIFT
cat > "$work/Tests/ControlsTests.swift" <<'SWIFT'
import XCTest
final class ControlsTests: XCTestCase {
 @MainActor func testRetryPreservesLibraryFiltersAndSort() {
  checkRecovery(recent: false, filter: "Unwatched", expected: "Recovered Unwatched All Date Added")
 }
 @MainActor func testRetryPreservesRecentFiltersAndSort() {
  checkRecovery(recent: true, filter: "Movies", expected: "Recovered All Movies Date Added")
 }
 @MainActor func checkRecovery(recent: Bool, filter: String, expected: String) {
  let app = XCUIApplication(); app.launchArguments = recent ? ["recover", "recent"] : ["recover"]; app.launch()
  XCTAssertTrue(app.buttons[filter].waitForExistence(timeout: 10))
  app.buttons[filter].tap()
  app.buttons["Name"].tap(); app.buttons["Date Added"].tap()
  let retry = app.buttons["Retry"]
  capture("grid-error-\(filter)")
  guard retry.waitForExistence(timeout: 3) else { XCTFail("Missing visible Retry"); return }
  retry.tap()
  XCTAssertTrue(app.buttons[expected].waitForExistence(timeout: 5))
  XCTAssertTrue(app.buttons[filter].isSelected)
  capture("grid-recovered-\(filter)")
 }
 @MainActor func testFilterSelectionTraits() {
  let app = XCUIApplication(); app.launch()
  let all = app.buttons["All"]; let unwatched = app.buttons["Unwatched"]
  XCTAssertTrue(all.waitForExistence(timeout: 10)); XCTAssertTrue(all.isSelected); XCTAssertFalse(unwatched.isSelected)
  unwatched.tap()
  XCTAssertTrue(unwatched.isSelected); XCTAssertFalse(all.isSelected)
  capture("library-selection")
 }
 @MainActor func testMediaTypeSelectionTraits() {
  let app = XCUIApplication(); app.launchArguments = ["recent"]; app.launch()
  let all = app.buttons["All"]; let movies = app.buttons["Movies"]
  XCTAssertTrue(all.waitForExistence(timeout: 10)); XCTAssertTrue(all.isSelected); XCTAssertFalse(movies.isSelected)
  movies.tap()
  XCTAssertTrue(movies.isSelected); XCTAssertFalse(all.isSelected)
  capture("recent-selection")
 }
 @MainActor func testSeasonSelectionTraits() {
  let app = XCUIApplication(); app.launchArguments = ["seasons"]; app.launch()
  let one = app.buttons["Season 1"]; let two = app.buttons["Season 2"]
  XCTAssertTrue(one.waitForExistence(timeout: 10)); XCTAssertTrue(one.isSelected); XCTAssertFalse(two.isSelected)
  two.tap()
  XCTAssertTrue(two.isSelected); XCTAssertFalse(one.isSelected)
  capture("season-selection")
 }
 @MainActor func capture(_ name: String) {
  let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
  attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
 }
}
SWIFT
cat > "$work/project.yml" <<'YAML'
name: LibraryControlsVerification
options:
  deploymentTarget:
    iOS: "26.0"
settings:
  base:
    SWIFT_VERSION: "6.2"
    CODE_SIGNING_ALLOWED: NO
    GENERATE_INFOPLIST_FILE: YES
    PRODUCT_BUNDLE_IDENTIFIER: test.seer.librarycontrols.$(PRODUCT_NAME:rfc1034identifier)
targets:
  JellyfinClient:
    type: framework
    platform: iOS
    sources: [Client]
  SeerCore:
    type: framework
    platform: iOS
    sources: [Core]
  OfflineSync:
    type: framework
    platform: iOS
    sources: [Offline]
  PlaybackClient:
    type: framework
    platform: iOS
    sources: [Playback]
  SeerUI:
    type: framework
    platform: iOS
    sources: [UI]
  Harness:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - target: JellyfinClient
      - target: SeerCore
      - target: OfflineSync
      - target: PlaybackClient
      - target: SeerUI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.librarycontrols
  ControlsTests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: Harness
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.librarycontrols.tests
schemes:
  Harness:
    build:
      targets:
        Harness: all
    test:
      targets: [ControlsTests]
YAML
xcodegen generate --spec "$work/project.yml"
sim=$(xcrun simctl create "Library controls isolated" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
set +e
xcodebuild test -project "$work/LibraryControlsVerification.xcodeproj" -scheme Harness "$@" \
 -destination "platform=iOS Simulator,id=$sim" -jobs 2 -parallel-testing-enabled NO \
 -collect-test-diagnostics never -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
 -derivedDataPath "$work/DerivedData" -clonedSourcePackagesDirPath "$work/Packages" \
 -resultBundlePath "$work/Result.xcresult" CODE_SIGNING_ALLOWED=NO > "$evidence/build.log" 2>&1
result=$?
set -e
xcrun xcresulttool export attachments --path "$work/Result.xcresult" --output-path "$evidence" || true
xcrun xcresulttool get test-results summary --path "$work/Result.xcresult" > "$evidence/summary.json" || true
exit "$result"
