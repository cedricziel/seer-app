#!/bin/sh
# Usage: internal-url-settings-tests.sh SIMULATOR_RUNTIME_IDENTIFIER EVIDENCE_DIRECTORY [before]
set -eu
repo_root=$(cd "$(dirname "$0")/../../../.." && pwd)
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/seer-internal-settings.XXXXXX")
simulator_id=
cleanup() {
    if [ -n "$simulator_id" ]; then
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
        xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
    fi
    rm -rf "$verify_dir"
}
trap cleanup EXIT HUP INT TERM
runtime=${1:?Pass an available iOS simulator runtime identifier}
evidence=${2:?Pass an evidence directory outside the checkout}
case "$evidence" in
    /*) ;;
    *) echo "Evidence directory must be absolute and outside the checkout" >&2; exit 1 ;;
esac
case "$evidence" in
    "$repo_root"|"$repo_root"/*) echo "Keep evidence outside the checkout" >&2; exit 1 ;;
esac
mkdir -p "$evidence" "$verify_dir/Core" "$verify_dir/App" "$verify_dir/Tests"
if [ "${3:-after}" = before ]; then
    git -C "$repo_root" show origin/main:Features/Servers/InternalURLSettingsView.swift > "$verify_dir/App/InternalURLSettingsView.swift"
else
    cp "$repo_root/Features/Servers/InternalURLSettingsView.swift" "$verify_dir/App/"
fi
cp "$repo_root/Packages/SeerCore/Sources/SeerCore/Utilities/InternalServerURL.swift" \
    "$repo_root/Packages/SeerCore/Sources/SeerCore/Services/AuthErrorFormatter.swift" "$verify_dir/Core/"
cat > "$verify_dir/Core/Fixtures.swift" <<'SWIFT'
import CoreLocation
import Foundation
import Combine

public final class ServerConfiguration {
    public var internalJellyfinURL: URL? = URL(string: "ftp://server.local")
    public var internalNetworkSSIDs = ["Test Home"]
    public var hasInternalURL: Bool { internalJellyfinURL != nil }
    public init() {}
}

@MainActor
public final class WiFiSSIDMonitor: ObservableObject {
    public static let shared = WiFiSSIDMonitor()
    @Published public var locationAuthorizationStatus: CLAuthorizationStatus = {
        if ProcessInfo.processInfo.arguments.contains("restricted") { return .restricted }
        if ProcessInfo.processInfo.arguments.contains("notDetermined") { return .notDetermined }
        return .denied
    }()
    public var currentSSID: String? { nil }
    public var hasLocationPermission: Bool { false }
    public func requestLocationPermission() {}
}
SWIFT
cat > "$verify_dir/App/Harness.swift" <<'SWIFT'
import SeerCore
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var saved = false
    func updateServer(_: ServerConfiguration) { saved = true }
}

@main
struct Harness: App {
    @StateObject private var appState = AppState()
    @State private var showingSettings = true
    private let config = ServerConfiguration()
    var body: some Scene {
        WindowGroup {
            Text(appState.saved ? "Saved" : "Not saved")
                .sheet(isPresented: $showingSettings) {
                    NavigationStack {
                        InternalURLSettingsView(config: config).environmentObject(appState)
                    }
                }
        }
    }
}
SWIFT
cat > "$verify_dir/Tests/RecoveryTests.swift" <<'SWIFT'
import XCTest

final class RecoveryTests: XCTestCase {
    @MainActor
    func testDeniedPermissionAndInvalidSave() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
        capture("denied-permission")
        if ProcessInfo.processInfo.environment["BASELINE"] == "1" {
            app.buttons["Save"].tap()
            XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 3))
            capture("unsupported-url-saved")
            return
        }
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertFalse(app.buttons["Grant Location Permission"].exists)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["internalURLValidationError"].exists)
        XCTAssertEqual(app.textFields["Internal URL"].value as? String, "ftp://server.local")
        XCTAssertTrue(app.buttons["Save"].exists)
        capture("invalid-url-inline")
        app.buttons["Add Network"].tap()
        let network = app.alerts.textFields.firstMatch
        XCTAssertTrue(network.waitForExistence(timeout: 3))
        network.tap()
        network.typeText("Manual WiFi")
        app.alerts.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Manual WiFi"].exists)
        let url = app.textFields["Internal URL"]
        url.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        url.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 64))
        url.typeText("http://192.168.1.10:8096")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testUnrequestedPermissionOffersPrompt() {
        let app = XCUIApplication()
        app.launchArguments = ["notDetermined"]
        app.launch()
        XCTAssertTrue(app.buttons["Grant Location Permission"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Add Network"].exists)
        XCTAssertFalse(app.buttons["Open Settings"].exists)
    }

    @MainActor
    func testRestrictedPermissionPreservesManualEntry() {
        if ProcessInfo.processInfo.environment["BASELINE"] == "1" { return }
        let app = XCUIApplication()
        app.launchArguments = ["restricted"]
        app.launch()
        XCTAssertTrue(app.staticTexts[
            "Location access is restricted. Check device restrictions to allow WiFi network detection."
        ].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Add Network"].exists)
        XCTAssertFalse(app.buttons["Grant Location Permission"].exists)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
SWIFT
cat > "$verify_dir/project.yml" <<'YAML'
name: InternalSettingsVerification
options:
  deploymentTarget:
    iOS: "26.0"
settings:
  base:
    SWIFT_VERSION: "6.2"
    CODE_SIGNING_ALLOWED: NO
    GENERATE_INFOPLIST_FILE: YES
targets:
  SeerCore:
    type: framework
    platform: iOS
    sources: [Core]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.ux.core
  Harness:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - target: SeerCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.ux.harness
  RecoveryTests:
    type: bundle.ui-testing
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: Harness
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: test.seer.ux.tests
schemes:
  Harness:
    build:
      targets:
        Harness: all
    test:
      targets: [RecoveryTests]
YAML
if [ "${3:-after}" = before ]; then
    export BASELINE=1
    # xcodebuild forwards TEST_RUNNER_ variables into the test runner.
    export TEST_RUNNER_BASELINE=1
fi
xcodegen generate --spec "$verify_dir/project.yml"
simulator_id=$(xcrun simctl create "Seer internal settings verification" \
    com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
xcodebuild test -project "$verify_dir/InternalSettingsVerification.xcodeproj" -scheme Harness \
    -destination "platform=iOS Simulator,id=$simulator_id" -jobs 2 \
    -derivedDataPath "$verify_dir/DerivedData" -clonedSourcePackagesDirPath "$verify_dir/Packages" \
    -resultBundlePath "$verify_dir/Results.xcresult" CODE_SIGNING_ALLOWED=NO
xcrun xcresulttool export attachments --path "$verify_dir/Results.xcresult" --output-path "$evidence"
