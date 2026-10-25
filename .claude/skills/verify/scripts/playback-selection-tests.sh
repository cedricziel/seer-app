#!/bin/sh
set -eu
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
work=$(mktemp -d /private/tmp/seer-selection-unit.XXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources/JellyfinClient" "$work/Sources/SeerApp" "$work/Tests/SelectionTests"
cp "$repo/Packages/JellyfinClient/Sources/JellyfinClient/Models/MediaItem.swift" "$work/Sources/JellyfinClient/"
cp "$repo/Features/Library/MediaPlaybackSelection.swift" "$work/Sources/SeerApp/"
cp "$repo/Tests/LibraryFeatureTests/MediaPlaybackSelectionTests.swift" "$work/Tests/SelectionTests/"
cat > "$work/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "SelectionVerification", platforms: [.macOS(.v14)], targets: [
.target(name: "JellyfinClient"),
.target(name: "SeerApp", dependencies: ["JellyfinClient"]),
.testTarget(name: "SelectionTests", dependencies: ["SeerApp", "JellyfinClient"])
])
SWIFT
CLANG_MODULE_CACHE_PATH="$work/clang" SWIFT_MODULECACHE_PATH="$work/swift" xcrun swift test --package-path "$work" --disable-sandbox --cache-path "$work/cache" --manifest-cache local --disable-swift-testing --jobs 2
