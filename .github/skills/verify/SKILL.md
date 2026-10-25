---
name: verify
description: Verify Seer changes with static checks and isolated builds, including telemetry configuration.
---

Run from the repository root:

For Jellyfin SDK changes, run the `JellyfinClientTests` and `PlaybackClientTests` targets in the isolated hosted test setup above. The URLProtocol fixture covers credential restoration and reauthentication, base paths and literal-plus queries, Quick Connect, library requests, error mapping, and complete playback JSON payloads. Stubbed responses do not establish live-server compatibility; record the server versions actually exercised against `docs/jellyfin-sdk-policy.md`.

For PiP restoration changes, run `.claude/skills/verify/scripts/pip-tests.sh SIMULATOR_RUNTIME_IDENTIFIER`. The script creates and deletes its own simulator and test project. It compiles the real manager and covers paused, buffering, and playing restoration plus artwork callback isolation without launching the app or loading media URLs.

1. Run `./scripts/swift-tools swiftlint lint --strict --no-cache`, `./scripts/swift-tools swiftformat --lint . --cache ignore`, `plutil -lint App/SeerApp/Info.plist`, and `git diff --check`. Separate pre-existing failures from changed-file failures.
2. Generate the Xcode project with `xcodegen generate`. Never edit the generated project directly.
3. For dependency maintenance, run `python3 -m unittest discover -s scripts -p 'test_*.py'` and `actionlint .github/workflows/dependency-audit.yml`. Run `python3 scripts/dependency_audit.py` with authenticated `gh`; exit 1 with a release table means unreviewed newer candidates exist, while an API or parsing error means the audit did not complete.
4. Build and test relevant schemes using a temporary directory outside the checkout for DerivedData, package clones, and result bundles. Use a disposable simulator and test credentials. Delete the simulator and temporary directory after verification, including on failure. Do not launch against existing simulator or user data. If isolation is unavailable, report runtime verification as blocked.

For download changes, run `DownloadClientTests/DownloadRegressionTests` and
`LibraryFeatureTests/EpisodeDownloadActionTests` on the disposable simulator.
They cover episode retry and cancellation actions, unknown content lengths, and
completed file sizes. Keep download fixtures on an ephemeral URLSession with a request trap, in-memory SwiftData, and temporary
storage. Do not instantiate the production background session in these fixtures.

For telemetry changes, check that CI and TestFlight workflows inject `OTLP_ENDPOINT`, `OTLP_AUTH_HEADER`, `OTLP_TENANT_ID`, and `OTLP_DATASET_ID` through Secrets.xcconfig into Info.plist. Keep real keys out of logs, fixtures, and version control. Verify traces, logs, and metrics against an explicitly selected deployment and tenant, with diagnostics consent enabled in the disposable app instance.

For Now Playing artwork ownership changes, run `PlaybackClientTests/PiPArtworkOwnershipTests` on an isolated simulator or through required CI. The injected loader controls delayed completions without network access. Cover closing playback, switching items that share an artwork URL, replacement metadata without artwork, and preserving the latest playback time when current artwork arrives.

Report static checks and simulator results separately from telemetry ingestion verification.

For request notification changes, run [scripts/request-tests.sh](scripts/request-tests.sh). This disposable macOS package tests the real poller, request models, and in-memory SwiftData store with controlled network responses and recorded notification output. It covers approval, decline, media completion with unchanged or completed request status, partial and 4K availability, unchanged polls, legacy cache baselines, and server scoping. It does not verify system notification delivery or app wiring; retain the native build and test checks above.

For media detail playback selection, run `.claude/skills/verify/scripts/playback-selection-tests.sh` from the repository root. It compiles the real selection logic, media model, and regression tests in a disposable macOS package with isolated compiler caches. It covers refreshed movie/episode resume ticks, explicit series episode selection, and fallback before details load without app state or network access.

For server URL resolution changes, run [the isolated resolver tests](../../../.claude/skills/verify/scripts/server-url-tests.sh). The macOS package uses the real resolver and configuration model with stubbed Wi-Fi and reachability, without app data or live servers. Verify the browsing connection gate separately on an isolated simulator.

For shared Swift tooling changes, run `python3 -m unittest scripts/test_swift_tools.py`.

For internal URL settings, run `SeerCoreTests/InternalServerURLTests` through required CI or an isolated test scheme. Cover blank input clearing the setting, HTTP/HTTPS hosts, unsupported schemes, and hostless input. Run `.claude/skills/verify/scripts/internal-url-settings-tests.sh SIMULATOR_RUNTIME_IDENTIFIER /absolute/scratch/evidence` for the isolated form flow. It covers denied, restricted, and unrequested location access, manual network entry, invalid Save retaining input with inline advice, and a corrected URL saving successfully. Append `before` to capture current main for comparison. The harness substitutes in-memory server and permission fixtures and does not verify system Settings or live SSID detection.
For shared Swift tooling changes, run `python3 -m unittest scripts/test_swift_tools.py`.
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

For notification permission or logout changes, run [the isolated notification tests](scripts/notification-tests.sh). The macOS harness uses an injected notification center and in-memory SwiftData. It covers Settings grants/revocations, inactive sessions, and retirement during authorization, including suppression of permission prompts. Run `NotificationClientTests` and `AuthFeatureTests/RequestPollingSchedulingTests` on a disposable iOS simulator for permanent poller retirement, in-flight fetch suppression, and cold-background rescheduling without an initialized poller. Check notification navigation after What's New or PiP dismissal and after switching saved servers; use test accounts and app data.
