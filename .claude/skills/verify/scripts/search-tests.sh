#!/bin/sh
set -eu

repo_root=$(cd "$(dirname "$0")/../../../.." && pwd)
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/seer-search-verify.XXXXXX")
trap 'rm -rf "$verify_dir"' EXIT HUP INT TERM

mkdir -p "$verify_dir/Sources/JellyfinClient" "$verify_dir/Sources/SeerApp" "$verify_dir/Tests/LibrarySearchTests"
cp "$repo_root/Packages/JellyfinClient/Sources/JellyfinClient/Models/MediaItem.swift" \
    "$verify_dir/Sources/JellyfinClient/MediaItem.swift"
cp "$repo_root/Features/Search/LibrarySearchModel.swift" "$verify_dir/Sources/SeerApp/LibrarySearchModel.swift"
cp "$repo_root/Tests/LibraryFeatureTests/LibrarySearchModelTests.swift" \
    "$verify_dir/Tests/LibrarySearchTests/LibrarySearchModelTests.swift"

cat > "$verify_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LibrarySearchVerification",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "JellyfinClient"),
        .target(name: "SeerApp", dependencies: ["JellyfinClient"]),
        .testTarget(name: "LibrarySearchTests", dependencies: ["SeerApp", "JellyfinClient"])
    ]
)
SWIFT

xcrun swift test --package-path "$verify_dir" --disable-sandbox \
    --cache-path "$verify_dir/cache" --manifest-cache local
