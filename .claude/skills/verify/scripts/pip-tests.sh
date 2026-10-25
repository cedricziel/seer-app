#!/bin/sh
set -eu

repo=$(cd "$(dirname "$0")/../../../.." && pwd)
runtime=${1:?Usage: pip-tests.sh SIMULATOR_RUNTIME_IDENTIFIER}
work=$(mktemp -d "${TMPDIR:-/tmp}/seer-pip-verify.XXXXXX")
sim=""
cleanup() {
    if [ -n "$sim" ]; then
        xcrun simctl shutdown "$sim" >/dev/null 2>&1 || true
        xcrun simctl delete "$sim" >/dev/null 2>&1 || true
    fi
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$work/Sources/JellyfinClient" "$work/Sources/PlaybackClient" "$work/Tests"
cp "$repo/Packages/JellyfinClient/Sources/JellyfinClient/Models/MediaItem.swift" "$work/Sources/JellyfinClient/"
cp "$repo/Packages/PlaybackClient/Sources/PlaybackClient/Services/PiPPlaybackManager.swift" "$work/Sources/PlaybackClient/"
cp "$repo"/Tests/PlaybackClientTests/PiP*Tests.swift "$work/Tests/"
cat > "$work/project.yml" <<'YAML'
name: PlaybackVerification
options:
  bundleIdPrefix: com.seer.isolated
  deploymentTarget:
    iOS: '26.0'
settings:
  base:
    SWIFT_VERSION: '6.2'
    GENERATE_INFOPLIST_FILE: YES
    CODE_SIGNING_ALLOWED: NO
targets:
  JellyfinClient:
    type: framework
    platform: iOS
    sources: [Sources/JellyfinClient]
  PlaybackClient:
    type: framework
    platform: iOS
    sources: [Sources/PlaybackClient]
    dependencies:
      - target: JellyfinClient
  PlaybackClientTests:
    type: bundle.unit-test
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: JellyfinClient
      - target: PlaybackClient
    settings:
      TEST_HOST: ''
      BUNDLE_LOADER: ''
schemes:
  PlaybackVerification:
    build:
      targets:
        PlaybackClientTests: [test]
    test:
      targets: [PlaybackClientTests]
YAML
xcodegen generate --spec "$work/project.yml"
sim=$(xcrun simctl create SeerPiPVerification com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")
xcrun simctl boot "$sim"
xcrun simctl bootstatus "$sim" -b
xcodebuild -project "$work/PlaybackVerification.xcodeproj" -scheme PlaybackVerification \
    -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "$work/DerivedData" \
    -clonedSourcePackagesDirPath "$work/Packages" -parallel-testing-enabled NO -jobs 2 \
    CODE_SIGNING_ALLOWED=NO test
