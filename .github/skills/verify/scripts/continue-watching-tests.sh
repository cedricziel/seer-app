#!/bin/sh
set -eu
# Usage: continue-watching-tests.sh SIMULATOR_RUNTIME_IDENTIFIER EVIDENCE_DIRECTORY [before]
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
runtime=${1:?Pass an installed iOS simulator runtime identifier}
evidence=${2:?Pass an absolute evidence directory outside the checkout}
mode=${3:-after}
case "$mode" in before|after) ;; *) exit 1 ;; esac
case "$evidence" in /*) ;; *) exit 1 ;; esac
case "$evidence" in "$repo"|"$repo"/*) exit 1 ;; esac
work=$(mktemp -d /private/tmp/seer-continue-watching.XXXXXX)
sim=
cleanup() {
 if [ -n "$sim" ]; then xcrun simctl shutdown "$sim" >/dev/null 2>&1 || true; xcrun simctl delete "$sim" >/dev/null 2>&1 || true; fi
 rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/App" "$work/Tests" "$evidence"
if [ "$mode" = before ]; then
 git -C "$repo" show origin/main:Features/Library/ContinueWatchingCards.swift > "$work/source.swift"
else
 cp "$repo/Features/Library/ContinueWatchingCards.swift" "$work/source.swift"
fi
sed '/^import Kingfisher$/d; /^import SeerUI$/d; /^#Preview/,$d' "$work/source.swift" > "$work/App/Cards.swift"
sed '/^#Preview/,$d' "$repo/Packages/SeerUI/Sources/SeerUI/WatchProgressIndicator.swift" > "$work/App/Progress.swift"
cat > "$work/App/Harness.swift" <<'SWIFT'
import SwiftUI
struct KFImage: View {
 init(_ url: URL?) {}
 func placeholder<Content: View>(@ViewBuilder _ content: () -> Content) -> Self { self }
 func fade(duration: Double) -> Self { self }
 func resizable() -> Self { self }
 var body: some View { Color.gray }
}
struct MediaContextMenuConfig {}
struct MediaContextMenuActions {}
extension View {
 func mediaContextMenu(config: MediaContextMenuConfig, actions: MediaContextMenuActions) -> some View { self }
}
@main struct Harness: App {
 @State private var resumes = 0
 var body: some Scene {
  WindowGroup {
   ScrollView {
    VStack(spacing: 16) {
     ContinueWatchingHeroCard(
      caption: "The Remarkably Long Series Name · S12 · E24",
      title: "A Very Long Episode Title That Should Never Cover Resume",
      subtitle: "1 hour and 12 minutes remaining in this episode",
      imageURL: nil, progress: 0.4, isDownloaded: ProcessInfo.processInfo.arguments.contains("downloaded"),
      showOfflineDimming: ProcessInfo.processInfo.arguments.contains("offline"),
      onResume: { resumes += 1 }
     )
     Text("Resumes: \(resumes)")
    }
    .frame(width: 320)
    .padding(.vertical, 24)
   }
   .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("AX5") ? .accessibility5 : .large)
   .preferredColorScheme(.dark)
  }
 }
}
SWIFT
cat > "$work/Tests/Flow.swift" <<'SWIFT'
import XCTest
final class Flow: XCTestCase {
 @MainActor func testCompactTextDoesNotCoverResume() {
  verifyLayout(arguments: [], name: "compact")
 }
 @MainActor func testAX5TextDoesNotCoverResume() {
  verifyLayout(arguments: ["AX5"], name: "AX5")
 }
 @MainActor func testAX5DownloadedBadgeDoesNotCoverCaption() {
  let app = XCUIApplication(); app.launchArguments = ["AX5", "offline", "downloaded"]; app.launch()
  let badge = app.staticTexts["Downloaded"]
  XCTAssertTrue(badge.waitForExistence(timeout: 10))
  let caption = app.staticTexts["THE REMARKABLY LONG SERIES NAME · S12 · E24"]
  XCTAssertFalse(badge.frame.intersects(caption.frame))
  XCTAssertTrue(app.buttons["Resume"].isEnabled)
 }
 @MainActor func testOfflineResumeRemainsDisabled() {
  let app = XCUIApplication(); app.launchArguments = ["offline"]; app.launch()
  XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 10))
  XCTAssertFalse(app.buttons["Resume"].isEnabled)
  XCTAssertTrue(app.staticTexts["Not downloaded"].exists)
 }
 @MainActor private func verifyLayout(arguments: [String], name: String) {
  let app = XCUIApplication(); app.launchArguments = arguments; app.launch()
  let resume = app.buttons["Resume"]
  XCTAssertTrue(resume.waitForExistence(timeout: 10))
  let title = app.staticTexts["A Very Long Episode Title That Should Never Cover Resume"]
  let subtitle = app.staticTexts["1 hour and 12 minutes remaining in this episode"]
  let caption = app.staticTexts["THE REMARKABLY LONG SERIES NAME · S12 · E24"]
  let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
  shot.name = name; shot.lifetime = .keepAlways; add(shot)
  XCTAssertTrue(title.exists); XCTAssertTrue(subtitle.exists); XCTAssertTrue(caption.exists)
  XCTAssertFalse(title.frame.intersects(resume.frame), "Title overlaps Resume: \(title.frame), \(resume.frame)")
  XCTAssertFalse(subtitle.frame.intersects(resume.frame), "Subtitle overlaps Resume: \(subtitle.frame), \(resume.frame)")
  XCTAssertFalse(caption.frame.intersects(resume.frame), "Caption overlaps Resume: \(caption.frame), \(resume.frame)")
  XCTAssertGreaterThanOrEqual(caption.frame.minY, 24)
  XCTAssertGreaterThanOrEqual(resume.frame.height, 44)
  XCTAssertTrue(resume.isHittable)
  resume.tap()
  XCTAssertTrue(app.staticTexts["Resumes: 1"].waitForExistence(timeout: 3))
 }
}
SWIFT
cat > "$work/project.yml" <<'YAML'
name: ContinueWatchingVerification
options:
  deploymentTarget:
    iOS: "26.0"
settings:
  base:
    SWIFT_VERSION: "6.2"
    GENERATE_INFOPLIST_FILE: YES
    CODE_SIGNING_ALLOWED: YES
    CODE_SIGN_IDENTITY: "-"
targets:
  Harness:
    type: application
    platform: iOS
    sources: [App]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.continue.harness
  FlowTests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: Harness
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.continue.tests
schemes:
  Harness:
    build:
      targets:
        Harness: all
    test:
      targets: [FlowTests]
YAML
xcodegen generate --spec "$work/project.yml"
sim=$(xcrun simctl create "Isolated Continue Watching verification" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
set +e
xcodebuild test -project "$work/ContinueWatchingVerification.xcodeproj" -scheme Harness \
 -destination "platform=iOS Simulator,id=$sim" -jobs 2 -parallel-testing-enabled NO \
 -collect-test-diagnostics never -test-timeouts-enabled YES -default-test-execution-time-allowance 90 \
 -derivedDataPath "$work/DerivedData" -clonedSourcePackagesDirPath "$work/Packages" \
 -resultBundlePath "$work/Result.xcresult" > "$evidence/build.log" 2>&1
result=$?
set -e
xcrun xcresulttool export attachments --path "$work/Result.xcresult" --output-path "$evidence" || true
xcrun xcresulttool get test-results summary --path "$work/Result.xcresult" > "$evidence/summary.json" || true
exit "$result"
