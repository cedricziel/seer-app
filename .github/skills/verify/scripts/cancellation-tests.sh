#!/bin/sh
set -eu
# Usage: cancellation-tests.sh SIMULATOR_RUNTIME_IDENTIFIER EVIDENCE_DIRECTORY [before]
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
runtime=${1:?Pass an installed iOS simulator runtime identifier}
evidence=${2:?Pass an absolute evidence directory outside the checkout}
mode=${3:-after}
case "$mode" in before|after) ;; *) exit 1 ;; esac
case "$evidence" in /*) ;; *) exit 1 ;; esac
case "$evidence" in "$repo"|"$repo"/*) exit 1 ;; esac
work=$(mktemp -d /private/tmp/seer-cancellation.XXXXXX)
sim=
cleanup() {
 if [ -n "$sim" ]; then xcrun simctl shutdown "$sim" >/dev/null 2>&1 || true; xcrun simctl delete "$sim" >/dev/null 2>&1 || true; fi
 rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/App" "$work/Client" "$work/Tests" "$evidence"
if [ "$mode" = before ]; then
 git -C "$repo" show origin/main:Features/Requests/RequestsView.swift > "$work/source.swift"
else
 cp "$repo/Features/Requests/RequestsView.swift" "$work/source.swift"
fi
printf 'import SwiftUI\nimport JellyseerrClient\n' > "$work/App/Details.swift"
sed -n '/^struct RequestDetailsSheet:/,/^#Preview/{ /^#Preview/!p; }' "$work/source.swift" >> "$work/App/Details.swift"
cp "$repo/Packages/JellyseerrClient/Sources/JellyseerrClient/Models/MediaRequest.swift" "$work/Client/"
cat > "$work/App/Harness.swift" <<'SWIFT'
import SwiftUI
import JellyseerrClient
@main struct Harness: App {
 @State private var show = true
 @State private var attempts = 0
 var request: MediaRequest {
  let status = ProcessInfo.processInfo.arguments.contains("approved") ? 2 : 1
  return try! JSONDecoder().decode(MediaRequest.self, from: Data("{\"id\":1,\"status\":\(status),\"createdAt\":\"2026-01-01\",\"updatedAt\":\"2026-01-01\",\"type\":\"movie\",\"is4k\":false,\"media\":{\"id\":1},\"requestedBy\":{\"id\":1,\"username\":\"Test User\"}}".utf8))
 }
 var body: some Scene {
  WindowGroup {
   Text("Attempts: \(attempts)").sheet(isPresented: $show) {
#if BEFORE
    RequestDetailsSheet(request: request, displayTitle: "Test Movie")
#else
    RequestDetailsSheet(request: request, displayTitle: "Test Movie", onCancel: {
     attempts += 1
     try await Task.sleep(for: .seconds(2))
     if attempts == 1 { throw URLError(.timedOut) }
    })
#endif
   }
  }
 }
}
SWIFT
cat > "$work/Tests/Flow.swift" <<'SWIFT'
import XCTest
final class Flow: XCTestCase {
 @MainActor func testConfirmationFailureAndRetry() {
  let app = XCUIApplication(); app.launch()
  XCTAssertTrue(app.navigationBars["Request Details"].waitForExistence(timeout: 10))
  capture("details")
  let cancel = app.buttons["Cancel Request"].firstMatch
  XCTAssertTrue(cancel.exists)
  guard cancel.exists else { return }
  cancel.tap()
  XCTAssertTrue(app.buttons["Keep Request"].waitForExistence(timeout: 3))
  capture("confirmation")
  app.buttons["Keep Request"].tap()
  XCTAssertFalse(app.buttons["Retry Cancellation"].exists)
  cancel.tap()
  app.buttons["Cancel Request"].firstMatch.tap()
  XCTAssertTrue(app.staticTexts["Cancelling Request…"].waitForExistence(timeout: 3))
  XCTAssertFalse(app.buttons["Done"].isEnabled)
  let retry = app.buttons["Retry Cancellation"]
  XCTAssertTrue(retry.waitForExistence(timeout: 6))
  capture("failure")
  retry.tap()
  XCTAssertTrue(app.staticTexts["Attempts: 2"].waitForExistence(timeout: 6))
 }
 @MainActor func testApprovedRequestHasNoCancellation() {
  let app = XCUIApplication(); app.launchArguments = ["approved"]; app.launch()
  XCTAssertTrue(app.navigationBars["Request Details"].waitForExistence(timeout: 10))
  XCTAssertFalse(app.buttons["Cancel Request"].exists)
 }
 @MainActor private func capture(_ name: String) {
  let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
  attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
 }
}
SWIFT
cat > "$work/project.yml" <<'YAML'
name: CancellationVerification
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
  JellyseerrClient:
    type: framework
    platform: iOS
    sources: [Client]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.cancel.client
  Harness:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - target: JellyseerrClient
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.cancel.harness
  FlowTests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: Harness
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.cancel.tests
schemes:
  Harness:
    build:
      targets:
        Harness: all
    test:
      targets: [FlowTests]
YAML
xcodegen generate --spec "$work/project.yml"
sim=$(xcrun simctl create "Isolated cancellation verification" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
flags=
if [ "$mode" = before ]; then flags=BEFORE; fi
set +e
xcodebuild test -project "$work/CancellationVerification.xcodeproj" -scheme Harness \
 -destination "platform=iOS Simulator,id=$sim" -jobs 2 -parallel-testing-enabled NO \
 -collect-test-diagnostics never -test-timeouts-enabled YES -default-test-execution-time-allowance 90 \
 -derivedDataPath "$work/DerivedData" -clonedSourcePackagesDirPath "$work/Packages" \
 -resultBundlePath "$work/Result.xcresult" SWIFT_ACTIVE_COMPILATION_CONDITIONS="$flags" \
 > "$evidence/build.log" 2>&1
result=$?
set -e
xcrun xcresulttool export attachments --path "$work/Result.xcresult" --output-path "$evidence" || true
xcrun xcresulttool get test-results summary --path "$work/Result.xcresult" > "$evidence/summary.json" || true
exit "$result"
