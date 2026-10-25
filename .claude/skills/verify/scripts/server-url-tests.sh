#!/bin/sh
set -eu

repo_root=$(cd "$(dirname "$0")/../../../.." && pwd)
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/seer-url-verify.XXXXXX")
trap 'rm -rf "$verify_dir"' EXIT HUP INT TERM

mkdir -p "$verify_dir/Sources/SeerCore" "$verify_dir/Tests/SeerCoreTests"
cp "$repo_root/Packages/SeerCore/Sources/SeerCore/Services/ServerURLResolver.swift" \
    "$repo_root/Packages/SeerCore/Sources/SeerCore/Models/ServerConfiguration.swift" \
    "$repo_root/Packages/SeerCore/Sources/SeerCore/Utilities/WiFiNetworkStatus.swift" \
    "$verify_dir/Sources/SeerCore/"
cp "$repo_root/Tests/SeerCoreTests/ServerURLResolverTests.swift" "$verify_dir/Tests/SeerCoreTests/"

cat > "$verify_dir/Sources/SeerCore/WiFiSSIDMonitor.swift" <<'SWIFT'
import Foundation

@MainActor
public final class WiFiSSIDMonitor: WiFiNetworkStatus {
    public static let shared = WiFiSSIDMonitor()
    public var currentSSID: String?
    public var isOnWiFi = false
    public var hasLocationPermission = false
    public func requestLocationPermission() {}
    public func refresh() {}
}
SWIFT

cat > "$verify_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ServerURLVerification",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SeerCore"),
        .testTarget(name: "SeerCoreTests", dependencies: ["SeerCore"])
    ]
)
SWIFT

xcrun swift test --package-path "$verify_dir" --disable-sandbox --jobs 2 \
    --cache-path "$verify_dir/cache" --manifest-cache local
