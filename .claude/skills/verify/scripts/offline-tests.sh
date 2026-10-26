#!/bin/sh
set -eu

repo_root=$(cd "$(dirname "$0")/../../../.." && pwd)
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/seer-offline-tests.XXXXXX")
trap 'rm -rf "$verify_dir"' EXIT HUP INT TERM

mkdir -p "$verify_dir/Sources/DownloadClient" "$verify_dir/Sources/JellyfinClient" \
    "$verify_dir/Sources/SeerApp" "$verify_dir/Tests/DownloadClientTests" "$verify_dir/Tests/DownloadPlaybackTests"
cp "$repo_root"/Packages/DownloadClient/Sources/DownloadClient/Models/*.swift \
    "$repo_root"/Packages/DownloadClient/Sources/DownloadClient/Persistence/*.swift \
    "$repo_root/Packages/DownloadClient/Sources/DownloadClient/Services/BackgroundSessionManager.swift" \
    "$repo_root/Packages/DownloadClient/Sources/DownloadClient/Services/DownloadStorage.swift" \
    "$repo_root/Packages/DownloadClient/Sources/DownloadClient/Services/DownloadStartClaims.swift" \
    "$verify_dir/Sources/DownloadClient/"
cp "$repo_root/Packages/JellyfinClient/Sources/JellyfinClient/Models/MediaItem.swift" \
    "$verify_dir/Sources/JellyfinClient/"
cp "$repo_root/Features/Downloads/DownloadActionFeedback.swift" "$verify_dir/Sources/SeerApp/"
cp "$repo_root/Features/Downloads/DownloadPlaybackDestination.swift" "$verify_dir/Sources/SeerApp/"
cp "$repo_root/Tests/DownloadClientTests/BackgroundSessionManagerTests.swift" \
    "$repo_root/Tests/DownloadClientTests/DownloadTransferTests.swift" \
    "$repo_root/Tests/DownloadClientTests/DownloadStartClaimsTests.swift" \
    "$repo_root/Tests/DownloadClientTests/DownloadStoragePathTests.swift" \
    "$repo_root/Tests/DownloadClientTests/DownloadPlaybackProgressTests.swift" \
    "$verify_dir/Tests/DownloadClientTests/"
cp "$repo_root/Tests/LibraryFeatureTests/DownloadActionFeedbackTests.swift" "$verify_dir/Tests/DownloadPlaybackTests/"
cp "$repo_root/Tests/LibraryFeatureTests/DownloadPlaybackTests.swift" "$verify_dir/Tests/DownloadPlaybackTests/"

cat > "$verify_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OfflineDownloadVerification",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DownloadClient"),
        .target(name: "JellyfinClient"),
        .target(name: "SeerApp", dependencies: ["DownloadClient", "JellyfinClient"]),
        .testTarget(name: "DownloadClientTests", dependencies: ["DownloadClient"]),
        .testTarget(name: "DownloadPlaybackTests", dependencies: ["SeerApp", "DownloadClient", "JellyfinClient"])
    ]
)
SWIFT

CLANG_MODULE_CACHE_PATH="$verify_dir/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$verify_dir/module-cache" \
xcrun swift test --package-path "$verify_dir" --disable-sandbox --jobs 2 \
    --cache-path "$verify_dir/cache" --manifest-cache local
