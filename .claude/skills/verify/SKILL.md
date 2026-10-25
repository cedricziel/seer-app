---
name: verify
description: Verify Seer changes with isolated search-model tests, native builds, hosted unit tests, and OpenAPI regeneration before a PR.
---

# Verify Seer

For PiP restoration changes, run `.claude/skills/verify/scripts/pip-tests.sh SIMULATOR_RUNTIME_IDENTIFIER`. The script creates and deletes its own simulator and test project. It compiles the real manager and covers paused, buffering, and playing restoration plus artwork callback isolation without launching the app or loading media URLs.

1. Check `git status --short`. Preserve unrelated changes and peer worktrees.
2. Run [scripts/search-tests.sh](scripts/search-tests.sh) for library-search changes. It compiles the real search model, Jellyfin media types, and regression tests in a disposable macOS Swift package. It does not launch the app or access credentials, preferences, or CloudKit. Requires macOS and the Xcode Swift toolchain. This checks model behavior, not SwiftUI integration.
3. Run [scripts/request-tests.sh](scripts/request-tests.sh) for request-loading changes. It compiles the real request view model, API models, scheduler, and SwiftData cache model in a disposable macOS package. The [AppState fixture](fixtures/RequestDependencies.swift) and [API fixture](fixtures/RequestService.swift) prevent credentials, preferences, CloudKit, and network access. Continuation-controlled tests cover stale server/filter/sort responses, refresh/pagination ownership, and actions on obsolete rows.
4. Use the versions and checksums in `scripts/swift-tools.lock`. Run `./scripts/swift-tools swiftlint lint --strict --no-cache` and `./scripts/swift-tools swiftformat --lint . --cache ignore`. Compare failures with the baseline. Format only changed files.
5. Run `openspec validate library-search-settings --strict` when changing that spec. For other changes, validate their change name.
6. Regenerate the project with `xcodegen generate`. Build iOS and tvOS with `xcodebuild`, a temporary derived-data directory, temporary cloned-package directory, and `CODE_SIGNING_ALLOWED=NO`. Use `-destination 'generic/platform=iOS Simulator'` or `-destination 'generic/platform=tvOS Simulator'`. These builds require SDK services and package downloads; do not mistake sandbox failures for source errors.
7. For runtime checks, create a dedicated simulator, use test servers and credentials, and delete the simulator in a cleanup trap. Never launch on a user's existing simulator or device. If isolation is unavailable, report runtime checks as unverified.
8. For dependency maintenance, run `python3 -m unittest discover -s scripts -p 'test_*.py'` and `actionlint .github/workflows/dependency-audit.yml`. Run `python3 scripts/dependency_audit.py` with authenticated `gh`; exit 1 with a release table means unreviewed newer candidates exist, while an API or parsing error means the audit did not complete.

For download changes, run `DownloadClientTests/DownloadRegressionTests` and
`LibraryFeatureTests/EpisodeDownloadActionTests` on the disposable simulator.
They cover episode retry and cancellation actions, unknown content lengths, and
completed file sizes. Keep download fixtures on an ephemeral URLSession with a request trap, in-memory SwiftData, and temporary
storage. Do not instantiate the production background session in these fixtures.

For server URL resolution changes, run [scripts/server-url-tests.sh](scripts/server-url-tests.sh). It runs the real resolver, SwiftData configuration, and resolver tests in a disposable macOS package with stubbed Wi-Fi and reachability. It does not access app data, credentials, or live servers. This checks resolution and cache behavior; verify the browsing connection gate separately on an isolated simulator.

Debug hosted unit tests enter `HostedUnitTestApp` through `SeerAppEntryPoint` when XCTest is injected. This bypasses `SeerApp.init` and its CloudKit stores, telemetry, and background services. UI tests still enter the production app because XCTest runs in a separate runner process. An unsigned host was verified with all 11 LibrarySearchModelTests on an isolated iOS simulator. Do not launch an unsigned production app to run hosted unit tests: CloudKit requires entitlements and can trap before the test suite starts. The SDK invalidDigitCount warning can appear during successful runs; inspect the crash report before diagnosing a startup timeout.

For catalog pagination, request-cache, or offline progress changes, include
`LibraryFeatureTests/CatalogSearchPaginationTests`,
`LibraryFeatureTests/RequestCacheTests`, and
`OfflineSyncTests/UserProgressSyncServiceTests` in the isolated native test run.
These suites use controlled search responses and in-memory SwiftData stores.
They cover stale pagination responses, preservation of requests outside a page
or filter, and progress isolation between servers with matching media IDs.

For onboarding persistence changes, run `AuthFeatureTests/OnboardingViewModelTests` on the dedicated simulator. Verify password and Quick Connect reauthentication preserve the saved UUID, settings, and server count while refreshing credentials. Manual and Bonjour onboarding must still create a new server. Keep SwiftData in memory and use test credentials.

For offline library initialization changes, run the hosted `LibraryFeatureTests/LibraryOfflineInitializationTests` suite on a disposable simulator with `-parallel-testing-enabled NO`. It uses an in-memory SwiftData store, fixed offline connectivity, temporary server credentials, and a URL protocol trap that rejects fixture-server requests. It covers home, independent library/recently-added grids, movie metadata, and series seasons/episodes. Use an empty `Config/Secrets.xcconfig` in a temporary source snapshot. Do not copy production secrets.

Check these journeys on an isolated simulator:

- Search defaults to Library without Jellyseerr; a result opens existing media details and playback.
- Query text survives Library/Catalog switches; server or Jellyfin credential changes clear prior search state.
- Blank queries, errors/retry, stale responses, task cancellation, and pagination behave correctly.
- Returning from details preserves loaded search pages.
- Every tab opens Settings; Servers, Downloads, Privacy & Diagnostics, and Send Feedback are reachable and dismiss back correctly.
- Library and Requests retain Refresh in their menus.
- Check iPhone portrait/landscape, iPad regular and split-view 1/3, 1/2, 2/3, tvOS focus, VoiceOver, AX5, and Reduce Motion.

Record feature snapshots on the same iOS runtime as CI, currently iOS 26.5. iOS 27 renders navigation controls and text differently even at the same snapshot dimensions. Review reference, failure, and difference attachments before replacing a baseline; keep comparison thresholds unchanged. If the standalone snapshot artifact is absent, export the suite's attachments from the xcresult bundle without `--only-failures`, which can omit the PNG attachments.

Native builds and visual checks can be blocked by existing source errors or unavailable simulator services. Record the exact blocker and leave those checks incomplete.

For Now Playing artwork ownership changes, run `PlaybackClientTests/PiPArtworkOwnershipTests` on an isolated simulator or through required CI. The injected loader controls delayed completions without network access. Cover closing playback, switching items that share an artwork URL, replacement metadata without artwork, and preserving the latest playback time when current artwork arrives.

## OpenAPI changes

Follow the pinned generator setup in [the API package guide](../../../Packages/JellyseerrAPI/README.md). Regenerate twice and compare output hashes to check determinism. Compile with `xcrun swift build --package-path Packages/JellyseerrAPI --scratch-path "$work/build"`, using a fresh `mktemp -d` directory for `work` and a cleanup trap. Use Xcode's Swift toolchain through `xcrun` so the compiler matches the selected SDK.

For telemetry installation-ID changes, run `SeerCoreTests/InstallationIDStoreTests`.
These tests use an in-memory Keychain boundary to cover UUID reuse, local-only
storage, unavailable reads, failed writes, concurrent creation, and invalid stored
values without accessing user credentials. Verify that `app.installation.id` is
added to the shared resource only when diagnostics are enabled. Run
`DiagnosticsPreferencesTests` and `DiagnosticsExporterTests` for default-on
preferences, legacy opt-out preservation, and export-time category gates.

For media detail playback selection, run `.claude/skills/verify/scripts/playback-selection-tests.sh` from the repository root. It compiles the real selection logic, media model, and regression tests in a disposable macOS package with isolated compiler caches. It covers refreshed movie/episode resume ticks, explicit series episode selection, and fallback before details load without app state or network access.

For typed App Intent requests, run `JellyseerrClientTests/RequestSearchMatchTests`
and `SeerCoreTests/Tier1IntentTests`. An explicit type must not fall back to the
other type, and owning a same-name movie must not suppress a show request.

For shared Swift tooling changes, run `python3 -m unittest scripts/test_swift_tools.py`.

For App Intents server identity changes, run `SeerCoreTests/AppEntityQueryTests`,
`SeerCoreTests/Tier1IntentTests`, and `SeerCoreTests/Tier2IntentTests` in the isolated
hosted test app. Cover duplicate item IDs across servers, saved entities targeting
an inactive server, and rejection of unbound entities. Legacy unqualified entity
IDs must require reselection instead of resolving against the active server.