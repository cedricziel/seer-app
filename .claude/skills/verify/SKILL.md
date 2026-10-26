---
name: verify
description: Verify Seer changes with isolated search and offline-download tests, native builds, hosted unit tests, and OpenAPI regeneration before a PR.
---

# Verify Seer

For Jellyfin SDK changes, run the `JellyfinClientTests` and `PlaybackClientTests` targets in the isolated hosted test setup above. The URLProtocol fixture covers credential restoration and reauthentication, base paths and literal-plus queries, Quick Connect, library requests, error mapping, and complete playback JSON payloads. Stubbed responses do not establish live-server compatibility; record the server versions actually exercised against `docs/jellyfin-sdk-policy.md`.

For PiP restoration changes, run `.claude/skills/verify/scripts/pip-tests.sh SIMULATOR_RUNTIME_IDENTIFIER`. The script creates and deletes its own simulator and test project. It compiles the real manager and covers paused, buffering, and playing restoration plus artwork callback isolation without launching the app or loading media URLs.

1. Check `git status --short`. Preserve unrelated changes and peer worktrees.
2. Run [scripts/search-tests.sh](scripts/search-tests.sh) for library-search changes. It compiles the real search model, Jellyfin media types, and regression tests in a disposable macOS Swift package. It does not launch the app or access credentials, preferences, or CloudKit. Requires macOS and the Xcode Swift toolchain. This checks model behavior, not SwiftUI integration.
   For offline downloads, run [scripts/offline-tests.sh](scripts/offline-tests.sh). It checks request cellular policies, HTTP response handling, stored playback destinations, and progress persistence and synchronization using real sources, temporary files, and in-memory SwiftData. Sessions are injected and never start real transfers. Native player integration remains in `LibraryFeatureTests/OfflinePlaybackProgressTests` and requires the isolated simulator procedure below.
3. Run [scripts/request-tests.sh](scripts/request-tests.sh) for request-loading changes. It compiles the real request view model, API models, scheduler, and SwiftData cache model in a disposable macOS package. The [AppState fixture](fixtures/RequestDependencies.swift) and [API fixture](fixtures/RequestService.swift) prevent credentials, preferences, CloudKit, and network access. Continuation-controlled tests cover stale server/filter/sort responses, refresh/pagination ownership, and actions on obsolete rows.
4. Use the versions and checksums in `scripts/swift-tools.lock`. Run `./scripts/swift-tools swiftlint lint --strict --no-cache` and `./scripts/swift-tools swiftformat --lint . --cache ignore`. Compare failures with the baseline. Format only changed files.
5. Run `openspec validate library-search-settings --strict` when changing that spec. For other changes, validate their change name.
6. Regenerate the project with `xcodegen generate`. Build iOS and tvOS with `xcodebuild`, a temporary derived-data directory, temporary cloned-package directory, and `CODE_SIGNING_ALLOWED=NO`. Use `-destination 'generic/platform=iOS Simulator'` or `-destination 'generic/platform=tvOS Simulator'`. These builds require SDK services and package downloads; do not mistake sandbox failures for source errors.
   Use a fresh DerivedData directory when a dependency moves a module between packages or changes its product type. Old products can shadow a new module even with correct package checkouts.
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

For notification permission or logout changes, run [the isolated notification tests](../../../.github/skills/verify/scripts/notification-tests.sh).
The macOS harness uses an injected notification center and in-memory SwiftData.
It covers Settings grants/revocations, inactive sessions, and retirement during authorization, including suppression of permission prompts.
Run `NotificationClientTests` and `AuthFeatureTests/RequestPollingSchedulingTests` on a disposable iOS simulator.
These cover permanent poller retirement, in-flight fetch suppression, and cold-background rescheduling before a poller exists.
Check navigation after What's New or PiP dismissal and after switching saved servers, using test accounts and app data.

For onboarding persistence changes, run `AuthFeatureTests/OnboardingViewModelTests` on the dedicated simulator. Verify password and Quick Connect reauthentication preserve the saved UUID, settings, and server count while refreshing credentials. Manual and Bonjour onboarding must still create a new server. Keep SwiftData in memory and use test credentials.

For offline library initialization changes, run the hosted `LibraryFeatureTests/LibraryOfflineInitializationTests` suite on a disposable simulator with `-parallel-testing-enabled NO`. It uses an in-memory SwiftData store, fixed offline connectivity, temporary server credentials, and a URL protocol trap that rejects fixture-server requests. It covers home, independent library/recently-added grids, offline filters and sorting, movie metadata, and series seasons/episodes isolated between server accounts. Use an empty `Config/Secrets.xcconfig` in a temporary source snapshot. Do not copy production secrets.

Check these journeys on an isolated simulator:

- Search defaults to Library without Jellyseerr; a result opens existing media details and playback.
- Query text survives Library/Catalog switches; server or Jellyfin credential changes clear prior search state.
- Blank queries, errors/retry, stale responses, task cancellation, and pagination behave correctly.
- Returning from details preserves loaded search pages.
- Every tab opens Settings; Servers, Downloads, Privacy & Diagnostics, and Send Feedback are reachable and dismiss back correctly.
- Library and Requests retain Refresh in their menus.
- Downloads opens completed movies and episodes with their stored server identity, including when another server is active and Library data is absent. Incomplete records have no Play action.
- Downloaded playback resumes locally, saves on native pause and dismissal, marks completion watched, and retains progress for retry after reconnect. WiFi-only requests must disallow cellular for fresh, resumed, and recovered tasks; use test destinations for any transfer checks.
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

For Shortcut navigation, run `SeerCoreTests/FlowmarkURLRouterTests`. Cover one-time
consumption, superseded lookups, and failed lookup retries. On an isolated app
instance, open a server-qualified Resume Watching URL from another tab and verify
that Library shows the target's details. Switch servers during resolution and
verify that stale results cannot open. Visual navigation remains unverified when
an isolated app instance is unavailable.

For shared Swift tooling changes, run `python3 -m unittest scripts/test_swift_tools.py`.

For App Intents server identity changes, run `SeerCoreTests/AppEntityQueryTests`,
`SeerCoreTests/Tier1IntentTests`, and `SeerCoreTests/Tier2IntentTests` in the isolated
hosted test app. Cover duplicate item IDs across servers, saved entities targeting
an inactive server, and rejection of unbound entities. Legacy unqualified entity
IDs must require reselection instead of resolving against the active server.

For Quick Connect recovery changes, run `AuthFeatureTests/OnboardingViewModelTests`
and `SeerUITests/QuickConnectViewSnapshotTests`. Cover expiration, failed code
requests, replacement-code loading, late responses after cancellation, and retry
against a saved server. Review expired, failed, and replacement-request snapshots;
unusable codes and Copy code must be absent while Request New Code and password
sign-in remain available on errors. Record baselines on the CI runtime.

For internal URL settings, run `SeerCoreTests/InternalServerURLTests` through required CI or an isolated test scheme. Cover blank input clearing the setting, HTTP/HTTPS hosts, unsupported schemes, and hostless input. Run `.claude/skills/verify/scripts/internal-url-settings-tests.sh SIMULATOR_RUNTIME_IDENTIFIER /absolute/scratch/evidence` for the isolated form flow. It covers denied, restricted, and unrequested location access, manual network entry, invalid Save retaining input with inline advice, and a corrected URL saving successfully. Append `before` to capture current main for comparison. The harness substitutes in-memory server and permission fixtures and does not verify system Settings or live SSID detection.
For release pipeline changes, run `ruby fastlane/tests/beta_test.rb` and
`ruby -c fastlane/Fastfile`. Validate the workflow with `actionlint`. Its existing
SC2016 warning comes from the literal xcconfig URL escaping expression.

Build the `SeerApp` scheme in Release with each destination:
`generic/platform=iOS`, `generic/platform=tvOS`, and `generic/platform=macOS`.
Keep build output and package checkouts in temporary directories outside the
working tree. Use an isolated source copy with an empty `Config/Secrets.xcconfig`
for unsigned builds. Never run signing bootstrap or upload lanes during local
verification. macOS must use the native SDK, with Catalyst disabled. Inspect
platform-specific entitlements and ensure the Mac app has App Sandbox enabled.

Release-lane tests cover iOS default behavior, tvOS signing and IPA selection,
macOS installer signing and PKG selection, and rejection of unknown targets. tvOS development signing fetches the certificate
without a development profile, so TestFlight does not require a registered Apple TV.

For TV request options, run [the selection regressions](scripts/request-season-tests.sh)
and [the sheet harness](scripts/request-sheet-tests.sh) with an available iOS simulator
runtime identifier and an absolute evidence directory outside the checkout. Obtain a build
coordinator grant before compilation. The sheet harness compiles both real sheets
with in-memory details providers, no service credentials or network, on a disposable
simulator. It covers loading submission, failed and empty details, retry, selected
seasons, 4K, movie submission, and rejection of a previous title's details. Pass
`after stale` as the final arguments to run only the two detail-ownership cases.
Append `before` to run the same assertions against
`origin/main`; loading and recovery assertions must fail before the fix. Review
exported screenshots. The harness does not verify live service responses.
For tvOS CloudKit releases, inspect the exported app entitlements and embedded provisioning profile. Both must include `aps-environment = production`; App Store Connect rejects CloudKit-enabled tvOS apps without it. Confirm upload validation in the release workflow.

For library-grid recovery and selection accessibility, run
[scripts/library-controls-tests.sh](scripts/library-controls-tests.sh) with an available
iOS runtime identifier and an absolute evidence directory outside the checkout.
Obtain a build coordinator grant first. The harness compiles the real grid and series
section with fixture models, in-memory SwiftData, no credentials, and no network.
It uses a disposable simulator and `-jobs 2`. It checks visible Retry, retained
watch/type filters and sorting after recovery, and selected accessibility traits
before and after filter or season changes. Append `before` to test `origin/main`.
This checks view wiring and the accessibility tree, not live Jellyfin responses or
spoken VoiceOver output. Review the exported screenshots.

For Discover loading changes, run `LibraryFeatureTests/DiscoverLoadingTests`
and `LibraryFeatureTests/ServiceClientLifecycleTests` on a disposable simulator.
The ephemeral URLSession fixture covers total failure and retry, partial content,
independent genre failures, retained content after failed refresh, and stale
responses after server or credential changes. It uses in-memory SwiftData and
throwaway server credentials; it does not verify live Jellyseerr compatibility.
