#!/bin/sh
set -eu
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
work=$(mktemp -d /private/tmp/seer-request-seasons.XXXXXX)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/Sources/SeerApp" "$work/Tests/SelectionTests"
cp "$repo/Features/Discover/RequestSeasonSelection.swift" "$work/Sources/SeerApp/"
cp "$repo/Tests/LibraryFeatureTests/RequestSeasonSelectionTests.swift" "$work/Tests/SelectionTests/"
cat > "$work/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "RequestSeasonVerification", platforms: [.macOS(.v14)], targets: [
.target(name: "SeerApp"),
.testTarget(name: "SelectionTests", dependencies: ["SeerApp"])
])
SWIFT
CLANG_MODULE_CACHE_PATH="$work/clang" SWIFT_MODULECACHE_PATH="$work/swift" xcrun swift test --package-path "$work" --disable-sandbox --cache-path "$work/cache" --manifest-cache local --disable-swift-testing --jobs 2
