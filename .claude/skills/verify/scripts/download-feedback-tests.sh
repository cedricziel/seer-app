#!/bin/sh
set -eu
runtime=${1:?Pass a simulator runtime identifier}
evidence=${2:?Pass an absolute evidence directory outside the checkout}
mode=${3:-after}
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
work=$(mktemp -d /private/tmp/seer-download-feedback.XXXXXX)
simulator=""
cleanup() {
    if [ -n "$simulator" ]; then
        xcrun simctl shutdown "$simulator" >/dev/null 2>&1 || true
        xcrun simctl delete "$simulator" >/dev/null 2>&1 || true
    fi
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/App" "$work/Tests" "$evidence"
cp "$repo/Features/Downloads/DownloadActionFeedback.swift" "$work/App/"
cp "$repo/Features/Downloads/DownloadErrorAlert.swift" "$work/App/"
cp "$repo/Packages/DownloadClient/Sources/DownloadClient/Models/Download.swift" \
    "$repo/Packages/DownloadClient/Sources/DownloadClient/Models/DownloadState.swift" \
    "$repo/Packages/DownloadClient/Sources/DownloadClient/Models/DownloadQuality.swift" \
    "$repo/Packages/SeerUI/Sources/SeerUI/DownloadButton.swift" "$work/App/"
if [ "$mode" = before ]; then
    git -C "$repo" show origin/main:Features/Downloads/DownloadsView.swift > "$work/DownloadsView.swift"
else
    cp "$repo/Features/Downloads/DownloadsView.swift" "$work/DownloadsView.swift"
fi
python3 - "$work" <<'PY'
import pathlib,sys
work=pathlib.Path(sys.argv[1])
source=(work/'DownloadsView.swift').read_text()
row=source[source.index('struct DownloadRow:'):source.index('#Preview')]
(work/'App/DownloadRow.swift').write_text('import SwiftUI\n'+row)
PY
cat > "$work/App/Fixture.swift" <<'SWIFT'
import SwiftUI

final class DownloadStorage {
    nonisolated static let defaultSearchPathDirectory = FileManager.SearchPathDirectory.cachesDirectory
}

@MainActor
final class DownloadManager {
    func pauseDownload(_ id: UUID) async throws { throw FixtureError.storage }
    func resumeDownload(_ id: UUID) async throws { throw FixtureError.storage }
    func deleteDownload(_ id: UUID) async throws { throw FixtureError.storage }
}

struct PosterImage: View {
    let url: URL
    let cornerRadius: CGFloat
    var body: some View { Color.gray }
}

enum FixtureError: LocalizedError {
    case storage
    var errorDescription: String? { "Free up storage, then retry." }
}

@main
struct FixtureApp: App {
    var body: some Scene { WindowGroup { FixtureView() } }
}

struct FixtureView: View {
    @State private var feedback = DownloadActionFeedback()
    @State private var showEpisode = false
    private let manager = DownloadManager()
    private let download: Download = {
        let download = Download(serverID: "test-server", itemID: "test-movie", mediaSourceID: "source",
                                name: "Test movie", mediaType: "Movie")
        download.state = .failed
        download.errorMessage = "Server unavailable. Check your connection and retry."
        return download
    }()
    private var before: Bool { ProcessInfo.processInfo.arguments.contains("before") }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DownloadRow(download: download, manager: manager)
                Button("Episode details") { showEpisode = true }
            }
            .padding()
            .navigationTitle("Downloads")
        }
        .downloadErrorAlert(feedback, isActive: before || !showEpisode)
        .sheet(isPresented: $showEpisode) {
            if before {
                episode
            } else {
                episode.downloadErrorAlert(feedback)
            }
        }
    }

    private var episode: some View {
        Button("Download episode") {
            Task { await feedback.perform { throw FixtureError.storage } }
        }
    }
}
SWIFT
cat > "$work/Tests/FeedbackUITests.swift" <<'SWIFT'
import XCTest

final class FeedbackUITests: XCTestCase {
    @MainActor
    func testFailedRowShowsReasonAndRetryError() {
        let app = launch()
        capture(app, "failed-row")
        XCTAssertTrue(app.staticTexts["Server unavailable. Check your connection and retry."].exists)
        let retry = app.buttons["Retry download for Test movie"]
        XCTAssertTrue(retry.exists)
        if retry.exists {
            retry.tap()
            XCTAssertTrue(app.alerts["Download Failed"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.alerts.staticTexts["Free up storage, then retry."].exists)
            capture(app, "retry-error")
        }
    }

    @MainActor
    func testEpisodeSheetPresentsImmediateDownloadError() {
        let app = launch()
        app.buttons["Episode details"].tap()
        app.buttons["Download episode"].tap()
        XCTAssertTrue(app.alerts["Download Failed"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts["Free up storage, then retry."].exists)
        capture(app, "episode-error")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        if ProcessInfo.processInfo.environment["VERIFY_BEFORE"] == "1" { app.launchArguments = ["before"] }
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
SWIFT
cat > "$work/project.yml" <<'YAML'
name: DownloadFeedbackVerification
options:
  bundleIdPrefix: com.seer.verify
settings:
  base:
    IPHONEOS_DEPLOYMENT_TARGET: "26.0"
    SWIFT_VERSION: "6.0"
    SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
    GENERATE_INFOPLIST_FILE: YES
    CODE_SIGNING_ALLOWED: NO
    INFOPLIST_KEY_UILaunchScreen_Generation: YES
targets:
  Fixture:
    type: application
    platform: iOS
    sources: [App]
  FeedbackUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests]
    dependencies: [{target: Fixture}]
schemes:
  Fixture:
    build:
      targets: {Fixture: all, FeedbackUITests: [test]}
    test:
      targets: [FeedbackUITests]
      environmentVariables:
        VERIFY_BEFORE: "${VERIFY_BEFORE}"
YAML
if [ "$mode" = before ]; then
    export VERIFY_BEFORE=1
else
    export VERIFY_BEFORE=0
fi
(cd "$work" && xcodegen generate)
simulator=$(xcrun simctl create "Seer download feedback $mode" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
xcrun simctl boot "$simulator"
xcrun simctl bootstatus "$simulator" -b
set +e
xcodebuild test -project "$work/DownloadFeedbackVerification.xcodeproj" -scheme Fixture \
    -destination "platform=iOS Simulator,id=$simulator" -derivedDataPath "$work/DerivedData" \
    -clonedSourcePackagesDirPath "$work/Packages" -resultBundlePath "$evidence/$mode.xcresult" \
    -parallel-testing-enabled NO -jobs 2 -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
result=$?
set -e
xcrun xcresulttool export attachments --path "$evidence/$mode.xcresult" --output-path "$evidence/$mode-attachments" || true
exit "$result"
