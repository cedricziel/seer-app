#!/bin/sh
set -eu
# Usage: request-sheet-tests.sh SIMULATOR_RUNTIME_IDENTIFIER EVIDENCE_DIRECTORY [before] [stale]
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
runtime=${1:?Pass an available iOS simulator runtime identifier}
evidence=${2:?Pass an evidence directory outside the checkout}
mode=${3:-after}
filter=${4:-}
set --
if [ "$filter" = stale ]; then
 set -- -only-testing:SheetTests/SheetTests/testDiscoverStaleDetails \
  -only-testing:SheetTests/SheetTests/testSearchStaleDetails
elif [ -n "$filter" ]; then
 echo "Unknown test filter: $filter" >&2; exit 1
fi
case "$evidence" in
 /*) ;;
 *) echo "Evidence directory must be absolute" >&2; exit 1 ;;
esac
case "$evidence" in
 "$repo"|"$repo"/*) echo "Keep evidence outside the checkout" >&2; exit 1 ;;
esac
work=$(mktemp -d /private/tmp/ux004-ui.XXXXXX)
sim=
cleanup() {
 if [ -n "$sim" ]; then xcrun simctl shutdown "$sim" >/dev/null 2>&1 || true; xcrun simctl delete "$sim" >/dev/null 2>&1 || true; fi
 rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/App" "$work/Client" "$work/UI" "$work/Tests" "$evidence"
for path in Features/Discover/SharedRequestOptionsSheet.swift Features/Search/RequestOptionsSheet.swift; do
 if [ "$mode" = before ]; then git -C "$repo" show "origin/main:$path" > "$work/App/$(basename "$path")"; else cp "$repo/$path" "$work/App/"; fi
done
cp "$repo/Features/Discover/RequestSeasonSelection.swift" "$work/App/"
cp "$repo/Packages/JellyseerrClient/Sources/JellyseerrClient/Models/SearchResult.swift" "$work/Client/"
# TV details require only this genre type in the fixture module.
sed -n '/^public struct TVDetails:/,/^\/\/ MARK: - Discover Models/p' "$repo/Packages/JellyseerrClient/Sources/JellyseerrClient/JellyseerrService.swift" > "$work/Client/TVDetails.swift"
cat > "$work/Client/Genre.swift" <<'SWIFT'
public struct MovieDetails { public struct Genre: Codable, Sendable { public let id: Int; public let name: String } }
SWIFT
cp "$repo/Packages/SeerUI/Sources/SeerUI/MediaPlaceholderColor.swift" "$work/UI/"
cat > "$work/App/Harness.swift" <<'SWIFT'
import SwiftUI
import JellyseerrClient

enum MediaKind { case movie, tvShow }
struct MediaTypeBadge: View {
 let type: MediaKind
 var body: some View { Text(type == .movie ? "Movie" : "TV Show").font(.caption) }
}
@MainActor
final class SearchViewModel: ObservableObject {
 @Published var isLoadingTVDetails = false
 @Published var tvDetails: TVDetails?
 var hasSeasons: Bool { !availableSeasons.isEmpty }
 var availableSeasons: [TVDetails.Season] { tvDetails?.seasons?.filter { $0.seasonNumber > 0 } ?? [] }
 init() {
  let args = ProcessInfo.processInfo.arguments
  isLoadingTVDetails = args.contains("loading")
  if args.contains("empty") { tvDetails = details(empty: true) }
  if args.contains("loaded") { tvDetails = details(empty: false) }
  if args.contains("stale") {
   tvDetails = try! JSONDecoder().decode(TVDetails.self, from: Data(
    #"{"id":41,"name":"Old Show","seasons":[{"id":99,"seasonNumber":99,"name":"Season 99"}]}"#.utf8
   ))
  }
 }
 func details(empty: Bool) -> TVDetails {
  let seasons = empty ? "[]" : "[{\"id\":1,\"seasonNumber\":1,\"name\":\"Season 1\"},{\"id\":2,\"seasonNumber\":2,\"name\":\"Season 2\"}]"
  return try! JSONDecoder().decode(TVDetails.self, from: Data("{\"id\":42,\"name\":\"Test Show\",\"seasons\":\(seasons)}".utf8))
 }
 func loadTVDetails(tmdbId: Int) async {
  isLoadingTVDetails = true
  tvDetails = nil
  await Task.yield()
  tvDetails = details(empty: false)
  isLoadingTVDetails = false
 }
}
@main
struct Harness: App {
 @StateObject private var provider = SearchViewModel()
 @State private var submitted = ""
 var result: SearchResult {
  let type = ProcessInfo.processInfo.arguments.contains("movie") ? "movie" : "tv"
  return try! JSONDecoder().decode(SearchResult.self, from: Data("{\"id\":42,\"mediaType\":\"\(type)\",\"name\":\"Test Show\"}".utf8))
 }
 var body: some Scene {
  WindowGroup {
   if submitted.isEmpty {
    if ProcessInfo.processInfo.arguments.contains("search") {
     RequestOptionsSheet(result: result, viewModel: provider, canRequest4K: true) { seasons, fourK in
      submitted = "Submitted \(seasons?.description ?? "movie") 4K \(fourK)"
     }
    } else {
     SharedRequestOptionsSheet(result: result, provider: provider, canRequest4K: true) { seasons, fourK in
      submitted = "Submitted \(seasons?.description ?? "movie") 4K \(fourK)"
     }
    }
   } else { Text(submitted) }
  }
 }
}
SWIFT
if [ "$mode" = before ]; then
 echo 'extension SearchViewModel: RequestOptionsProvider {}' >> "$work/App/Harness.swift"
fi
cat > "$work/Tests/SheetTests.swift" <<'SWIFT'
import XCTest
final class SheetTests: XCTestCase {
 @MainActor func checkLoading(_ sheet: String) {
  let app = XCUIApplication(); app.launchArguments = [sheet, "loading"]; app.launch()
  let request = app.buttons["Request"]
  XCTAssertTrue(request.waitForExistence(timeout: 10))
  capture("\(sheet)-loading")
  XCTAssertFalse(request.isEnabled)
 }
 @MainActor func checkRecovery(_ sheet: String) {
  let app = XCUIApplication(); app.launchArguments = [sheet]; app.launch()
  XCTAssertTrue(app.staticTexts["Unable to load seasons"].waitForExistence(timeout: 10))
  XCTAssertFalse(app.buttons["Request"].isEnabled)
  capture("\(sheet)-failure")
  app.buttons["Retry"].tap()
  XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Season 1'")).firstMatch.waitForExistence(timeout: 5))
  app.buttons.matching(NSPredicate(format: "label CONTAINS 'Season 1'")).firstMatch.tap()
  let fourK = app.switches.firstMatch
  fourK.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
  XCTAssertEqual(fourK.value as? String, "1")
  capture("\(sheet)-selection")
  app.buttons["Request"].tap()
  XCTAssertTrue(app.staticTexts["Submitted [2] 4K true"].waitForExistence(timeout: 5))
 }
 @MainActor func checkEmpty(_ sheet: String) {
  let app = XCUIApplication(); app.launchArguments = [sheet, "empty"]; app.launch()
  XCTAssertTrue(app.staticTexts["No seasons available"].waitForExistence(timeout: 10))
  XCTAssertFalse(app.buttons["Request"].isEnabled)
  capture("\(sheet)-empty")
  XCTAssertTrue(app.buttons["Retry"].exists)
 }
 @MainActor func checkMovie(_ sheet: String) {
  let app = XCUIApplication(); app.launchArguments = [sheet, "movie", "loading"]; app.launch()
  XCTAssertTrue(app.buttons["Request"].waitForExistence(timeout: 10))
  XCTAssertTrue(app.buttons["Request"].isEnabled)
  app.buttons["Request"].tap()
  XCTAssertTrue(app.staticTexts["Submitted movie 4K false"].waitForExistence(timeout: 5))
 }
 @MainActor func checkStaleDetails(_ sheet: String) {
  let app = XCUIApplication(); app.launchArguments = [sheet, "stale"]; app.launch()
  XCTAssertTrue(app.buttons["Request"].waitForExistence(timeout: 10))
  XCTAssertFalse(app.buttons["Request"].isEnabled)
  XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Season 99'")).firstMatch.exists)
  capture("\(sheet)-stale-details")
  app.buttons["Retry"].tap()
  XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Season 2'")).firstMatch.waitForExistence(timeout: 5))
  app.buttons["Request"].tap()
  XCTAssertTrue(app.staticTexts["Submitted [1, 2] 4K false"].waitForExistence(timeout: 5))
 }
 @MainActor func testDiscoverStaleDetails() { checkStaleDetails("discover") }
 @MainActor func testSearchStaleDetails() { checkStaleDetails("search") }
 @MainActor func testDiscoverLoading() { checkLoading("discover") }
 @MainActor func testSearchLoading() { checkLoading("search") }
 @MainActor func testDiscoverRecovery() { checkRecovery("discover") }
 @MainActor func testSearchRecovery() { checkRecovery("search") }
 @MainActor func testDiscoverEmpty() { checkEmpty("discover") }
 @MainActor func testSearchEmpty() { checkEmpty("search") }
 @MainActor func testDiscoverMovie() { checkMovie("discover") }
 @MainActor func testSearchMovie() { checkMovie("search") }
 @MainActor func capture(_ name: String) {
  let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
 }
}
SWIFT
cat > "$work/project.yml" <<'YAML'
name: RequestSeasonVerification
options:
  deploymentTarget:
    iOS: "26.0"
settings:
  base:
    SWIFT_VERSION: "6.2"
    CODE_SIGNING_ALLOWED: NO
    GENERATE_INFOPLIST_FILE: YES
targets:
  JellyseerrClient:
    type: framework
    platform: iOS
    sources: [Client]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.ux004.client
  SeerUI:
    type: framework
    platform: iOS
    sources: [UI]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.ux004.ui
  Harness:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - target: JellyseerrClient
      - target: SeerUI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.ux004.harness
  SheetTests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: Harness
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.ux004.tests
schemes:
  Harness:
    build:
      targets:
        Harness: all
    test:
      targets: [SheetTests]
YAML
xcodegen generate --spec "$work/project.yml"
sim=$(xcrun simctl create "UX004 isolated sheets" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
set +e
xcodebuild test -project "$work/RequestSeasonVerification.xcodeproj" -scheme Harness "$@" \
 -destination "platform=iOS Simulator,id=$sim" -jobs 2 -parallel-testing-enabled NO \
 -collect-test-diagnostics never -test-timeouts-enabled YES \
 -default-test-execution-time-allowance 120 -derivedDataPath "$work/DerivedData" \
 -clonedSourcePackagesDirPath "$work/Packages" -resultBundlePath "$work/Result.xcresult" \
 CODE_SIGNING_ALLOWED=NO > "$evidence/build.log" 2>&1
result=$?
set -e
xcrun xcresulttool export attachments --path "$work/Result.xcresult" --output-path "$evidence" || true
xcrun xcresulttool get test-results summary --path "$work/Result.xcresult" > "$evidence/summary.json" || true
exit "$result"
