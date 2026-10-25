#!/bin/sh
set -eu
repo_root=$(cd "$(dirname "$0")/../../../.." && pwd)
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/seer-requests-verify.XXXXXX")
trap 'rm -rf "$verify_dir"' EXIT HUP INT TERM
mkdir -p "$verify_dir/Sources/SeerCore" "$verify_dir/Sources/JellyseerrClient" \
    "$verify_dir/Sources/SeerApp" "$verify_dir/Tests/RequestTests"
cp "$repo_root/.claude/skills/verify/fixtures/RequestDependencies.swift" "$verify_dir/Sources/SeerCore/"
cp "$repo_root/Packages/SeerCore/Sources/SeerCore/Models/CachedRequest.swift" "$verify_dir/Sources/SeerCore/"
cp "$repo_root/Packages/SeerCore/Sources/SeerCore/Services/RefreshScheduler.swift" "$verify_dir/Sources/SeerCore/"
cp "$repo_root/Packages/JellyseerrClient/Sources/JellyseerrClient/Models/MediaRequest.swift" "$verify_dir/Sources/JellyseerrClient/"
cp "$repo_root/Packages/JellyseerrClient/Sources/JellyseerrClient/Models/SearchResult.swift" "$verify_dir/Sources/JellyseerrClient/"
cp "$repo_root/.claude/skills/verify/fixtures/RequestService.swift" "$verify_dir/Sources/JellyseerrClient/"
sed -n '/^public struct MovieDetails:/,/^\/\/ MARK: - Discover Models/p' \
    "$repo_root/Packages/JellyseerrClient/Sources/JellyseerrClient/JellyseerrService.swift" \
    > "$verify_dir/Sources/JellyseerrClient/Details.swift"
cp "$repo_root/Features/Requests/RequestsViewModel.swift" "$verify_dir/Sources/SeerApp/"
cp "$repo_root/Tests/LibraryFeatureTests/RequestsResponseIsolationTests.swift" "$verify_dir/Tests/RequestTests/"
cp "$repo_root/Tests/LibraryFeatureTests/RequestCacheTests.swift" "$verify_dir/Tests/RequestTests/"
cat > "$verify_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "RequestVerification", platforms: [.macOS(.v14)], targets: [
    .target(name: "SeerCore"), .target(name: "JellyseerrClient"),
    .target(name: "SeerApp", dependencies: ["SeerCore", "JellyseerrClient"]),
    .testTarget(name: "RequestTests", dependencies: ["SeerApp", "JellyseerrClient", "SeerCore"])
])
SWIFT
CLANG_MODULE_CACHE_PATH="$verify_dir/clang-cache" SWIFT_MODULECACHE_PATH="$verify_dir/swift-cache" \
xcrun swift test --package-path "$verify_dir" --disable-sandbox \
    --cache-path "$verify_dir/cache" --manifest-cache local --disable-swift-testing --jobs 4
