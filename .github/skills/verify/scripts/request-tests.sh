#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/../../../.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/seer-request-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources/JellyseerrClient" "$work/Sources/NotificationClient" "$work/Tests/NotificationClientTests"
cat > "$work/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "RequestRegression",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "JellyseerrClient"),
        .target(name: "NotificationClient", dependencies: ["JellyseerrClient"]),
        .testTarget(name: "NotificationClientTests", dependencies: ["NotificationClient", "JellyseerrClient"])
    ]
)
SWIFT
cp "$repo/Packages/JellyseerrClient/Sources/JellyseerrClient/Models/MediaRequest.swift" "$work/Sources/JellyseerrClient/"
for file in Models/CachedRequestStatus Models/NotificationPreferences Services/NotificationStore Services/RequestStatusPoller; do
    cp "$repo/Packages/NotificationClient/Sources/NotificationClient/$file.swift" "$work/Sources/NotificationClient/"
done
cp "$repo/Tests/NotificationClientTests/RequestStatusPollerTests.swift" "$work/Tests/NotificationClientTests/"
cp "$repo/Tests/NotificationClientTests/NotificationStoreTests.swift" "$work/Tests/NotificationClientTests/"
# Only external boundaries are replaced. Tests supply responses and record notifications.
cat > "$work/Sources/JellyseerrClient/JellyseerrService.swift" <<'SWIFT'
import Foundation
public actor JellyseerrService {
    public enum Filter { case all }
    public enum Sort { case modified }
    public init(serverURL: URL, apiKey: String) {}
    public func getRequests(take: Int, skip: Int, filter: Filter, sort: Sort) async throws -> RequestsResponse {
        fatalError("Tests must use controlled responses")
    }
}
SWIFT
cat > "$work/Sources/NotificationClient/RequestNotificationService.swift" <<'SWIFT'
@MainActor public final class RequestNotificationService {
    public func notifyRequestStatusChanges(_ changes: [RequestStatusChange], serverID: String) async {
        fatalError("Tests must use the notification recorder")
    }
}
SWIFT
CLANG_MODULE_CACHE_PATH="$work/clang-cache" SWIFT_MODULECACHE_PATH="$work/swift-cache" \
xcrun swift test --package-path "$work" --scratch-path "$work/build" --cache-path "$work/cache"
