#!/bin/bash
# Usage: notification-tests.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/seer-notification-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

source_root="$test_root/Sources/NotificationClient"
suite_root="$test_root/Tests/NotificationClientTests"
mkdir -p "$source_root" "$suite_root"

for source in \
    Core/NotificationManager.swift \
    Core/NotificationCenterClient.swift \
    Core/NotificationCategories.swift \
    Services/NotificationStore.swift \
    Services/RequestNotificationService.swift \
    Models/NotificationPreferences.swift \
    Models/CachedRequestStatus.swift; do
    cp "$repo_root/Packages/NotificationClient/Sources/NotificationClient/$source" "$source_root/"
done

for suite in NotificationManagerTests RequestNotificationLifecycleTests; do
    cp "$repo_root/Tests/NotificationClientTests/$suite.swift" "$suite_root/"
done

cat > "$test_root/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NotificationTests",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "NotificationClient"),
        .testTarget(name: "NotificationClientTests", dependencies: ["NotificationClient"])
    ]
)
SWIFT

export CLANG_MODULE_CACHE_PATH="$test_root/modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$test_root/modules"

developer_root="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
swift="$developer_root/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
xctest="$developer_root/usr/bin/xctest"
if [[ ! -x "$swift" || ! -x "$xctest" ]]; then
    echo "Select a full Xcode installation with xcode-select before running notification tests." >&2
    exit 1
fi

"$swift" build --build-tests \
    --package-path "$test_root" \
    --scratch-path "$test_root/build" \
    --cache-path "$test_root/cache" \
    --config-path "$test_root/config" \
    --security-path "$test_root/security" \
    --disable-sandbox \
    --jobs 2

test_bundle="$(find "$test_root/build" -type d -name NotificationClientTests.xctest -print -quit)"
if [[ -z "$test_bundle" ]]; then
    echo "NotificationClientTests.xctest was not produced by the build." >&2
    exit 1
fi
"$xctest" "$test_bundle"
