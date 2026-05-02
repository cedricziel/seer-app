<!--
TDD discipline (REQUIRED): Tests group MUST come before Implementation.
Implementation tasks cite which test they make pass.
Final task in each group: run `make lint` and `make format`.
-->

## 1. Setup

- [x] 1.1 Add `NSLocalNetworkUsageDescription` and `NSBonjourServices = ["_jellyfin._tcp"]` to `App/SeerApp/Info.plist` (or the equivalent xcconfig path under `project.yml`); regenerate via `make generate`.
- [x] 1.2 Introduce a runtime feature flag `streamlinedOnboardingEnabled` in `SeerCore` (default `false` initially), readable from `AppState`.
- [x] 1.3 Confirm `JellyfinAPI` SDK version pinned in `project.yml` (currently `from: "0.6.0"`) exposes `InitiateQuickConnect`, `GetQuickConnectState`, `AuthenticateWithQuickConnect`; bump if needed. — verified during exploration; all four endpoint files present in SDK checkout.
- [x] 1.4 Run `make generate && make build` to confirm scaffolding compiles before adding tests.

## 2. Tests (red) — JellyfinClient (BonjourDiscovery + QuickConnectSession)

- [x] 2.1 `BonjourDiscoveryTests.testEmitsDiscoveredServerWithin1500ms` using a stub `NWBrowser` (covers Scenario: "Browser emits discovered server within 1.5 seconds" in `local-server-discovery`).
- [x] 2.2 `BonjourDiscoveryTests.testStopsBrowserOnDeinit` (covers Scenario: "Browser stops on deinit").
- [x] 2.3 `BonjourDiscoveryTests.testPermissionDeniedFlag` (covers Scenario: "Permission denied on first browse").
- [x] 2.4 `BonjourDiscoveryTests.testRestartIsIdempotent` (covers Scenario: "Restart after stop").
- [x] 2.5 `QuickConnectSessionTests.testQuickConnectDisabledFallsBackImmediately` against a fake transport returning `{Enabled: false}` (covers Scenario: "Server has Quick Connect disabled" in `quick-connect-auth`).
- [x] 2.6 `QuickConnectSessionTests.testApprovedFlowExchangesSecretForToken` against a fake transport scripted with pending → approved → token (covers Scenario: "User approves Quick Connect on Jellyfin web").
- [x] 2.7 `QuickConnectSessionTests.testExpiryStopsPolling` (covers Scenario: "Code expires without approval").
- [x] 2.8 `QuickConnectSessionTests.testCancelStopsPollingAndDoesNotExchange` (covers Scenario: "User cancels Quick Connect").
- [x] 2.9 `QuickConnectSessionTests.testPollingCadenceBackoffAt30s` using injected clock (covers Scenario: "Backoff after 30 seconds").
- [x] 2.10 `QuickConnectSessionTests.testStateMachineExposesPendingApprovedExpiredFailedCancelled` (covers the "explicit states" requirement).
- [x] 2.11 Run `make lint` and `make format`.

## 3. Implementation (green) — JellyfinClient

- [x] 3.1 Add `DiscoveredJellyfinServer` value type (`name`, `host`, `port`, `URL`) in `Packages/JellyfinClient/Sources/JellyfinClient/`.
- [x] 3.2 Implement `BonjourDiscovery` (`@MainActor` `ObservableObject`, `discoveredServers`, `permissionDenied`, `start()`, `stop()`) wrapping `NWBrowser` for `_jellyfin._tcp` (makes 2.1, 2.2, 2.3, 2.4 pass).
- [x] 3.3 Add `QuickConnectSession` state machine type with `pending(code, secret)`, `approved(token)`, `expired`, `failed(Error)`, `cancelled` (makes 2.10 pass).
- [x] 3.4 Implement `QuickConnectSession.start(against:)` calling `GetQuickConnectEnabledAPI` + `InitiateQuickConnectAPI` (makes 2.5 setup work). — Implemented at HTTP layer (URLSession + injectable transport) for consistency with existing `JellyfinService` instead of binding to SDK types.
- [x] 3.5 Implement polling loop with injected clock at 1s × 30 then 3s thereafter, terminating on `approved` / `expired` / `cancelled` (makes 2.6, 2.7, 2.8, 2.9 pass).
- [x] 3.6 Implement secret-to-token exchange via `AuthenticateWithQuickConnectAPI` returning the same `AuthResponse` shape today's `JellyfinService.authenticate` returns (makes 2.6 pass).
- [x] 3.7 Run `make lint` and `make format`.

## 4. Tests (red) — SeerCore (URL learning + resolver fallback)

- [x] 4.1 `ServerInfoFetcherTests.testFetchesLocalAddressFromSystemInfoPublic` (covers `dual-URL learning` in design D3).
- [x] 4.2 `ServerInfoFetcherTests.testRejectsNonJellyfinResponse` (covers Scenario: "URL is not a Jellyfin server" in `server-onboarding`).
- [x] 4.3 `ServerURLResolverTests.testReachabilityFallbackUsedWhenSSIDUnknown` (covers design D4).
- [x] 4.4 `ServerURLResolverTests.testReachabilityProbeCachedFor60s` (covers risk mitigation in design).
- [x] 4.5 Run `make lint` and `make format`.

## 5. Implementation (green) — SeerCore

- [x] 5.1 Add `ServerInfoFetcher` in `Packages/SeerCore/Sources/SeerCore/Services/` that hits `/System/Info/Public` and returns `ServerInfo {productName, localAddress?, wanAddress?, version}` (makes 4.1, 4.2 pass). — Note: Jellyfin's public payload does not expose a WAN/ServerAddress field, only `LocalAddress`. `ServerInfo` carries `localAddress` only; WAN learning happens by remembering the URL the user entered.
- [x] 5.2 Extend `ServerURLResolver` with a probe method against `internalJellyfinURL` (1s timeout, `URLSession`-based) and a 60s in-memory cache keyed by network interface (makes 4.3, 4.4 pass). — Cache is keyed by `ServerConfiguration.id` (simpler and equivalent for the single-active-server case); revisit if multi-network simultaneous use becomes a thing.
- [x] 5.3 Run `make lint` and `make format`.

## 6. Tests (red) — SeerUI (JellyseerrConnectSheet)

- [x] 6.1 `JellyseerrConnectSheetTests.testValidatesCredentialsBeforeDismiss` against a fake `JellyseerrService` (covers Scenario: "Sheet validates credentials before dismissing" in `jellyseerr-on-demand`). — Implemented as `JellyseerrConnectSheetModelTests` against an injected `RecordingConnector` so SeerUI does not depend on JellyseerrClient.
- [x] 6.2 `JellyseerrConnectSheetTests.testPersistsCredentialsOnSuccess` (covers Scenario: "Sheet persists credentials on successful auth").
- [x] 6.3 `JellyseerrConnectSheetTests.testCancelDoesNotPersist` (covers Scenario: "User dismisses the sheet").
- [x] 6.4 Snapshot test `JellyseerrConnectSheet_iPhoneCompact` (portrait).
- [x] 6.5 Snapshot test `JellyseerrConnectSheet_iPadRegular` at 1/3 split. — Renders against `.iPadPro11` device config; full-window rather than split-view simulation since SnapshotTesting doesn't expose split widths directly.
- [x] 6.6 Run `make lint` and `make format`.

## 7. Implementation (green) — SeerUI

- [x] 7.1 Add `JellyseerrConnectSheet` SwiftUI view in `Packages/SeerUI/Sources/SeerUI/Onboarding/` with own view model exposing a completion callback (makes 6.1, 6.2, 6.3 pass). — Connector is an injected `(URL, String) async throws -> Void` closure so SeerUI stays free of JellyseerrClient/AppState dependencies; the calling Feature wires up `JellyseerrService.verifyAuth()` + `appState.saveJellyseerrCredentials`.
- [x] 7.2 Layout for iPhone compact portrait (makes 6.4 pass).
- [x] 7.3 Layout adaptation for iPad regular and split-view (makes 6.5 pass).
- [x] 7.4 Run `make lint` and `make format`. — Also added `SeerUITests` bundle (iOS-only, depends on SnapshotTesting). Compiled cross-platform shims for iOS-only modifiers (`navigationBarTitleDisplayMode`, `keyboardType`, `textInputAutocapitalization`) so SeerUI still builds for tvOS.

## 8. Tests (red) — Features/Auth (welcome screen + view model)

- [x] 8.1 `OnboardingViewModelTests.testWelcomeShowsManualEntryOnFreshInstall` (covers Scenario: "Fresh install with no iCloud and no Bonjour hits"). — Implemented as `WelcomeStateResolverTests.testFreshInstallShowsManualEntryAsPrimary` in SeerCoreTests against the pure resolver; resolver lives in SeerCore so it is unit-testable without a Features bundle.
- [x] 8.2 `OnboardingViewModelTests.testWelcomeShowsICloudServerWhenAvailable` (covers Scenario: "iCloud has a synced server"). — Implemented as `WelcomeStateResolverTests.testSyncedServerTakesPrecedenceOverBonjour` + `testMultipleSyncedSurfaceAsSecondary`.
- [x] 8.3 `OnboardingViewModelTests.testWelcomeShowsBonjourSuggestionsWhenAvailable` (covers Scenario: "Bonjour finds a server on the current Wi-Fi"). — Implemented as `WelcomeStateResolverTests.testBonjourSuggestionAppearsWhenNoSynced`.
- [x] 8.4 `OnboardingViewModelTests.testQuickConnectShownWhenServerEnabled` (covers Scenario: "Server has Quick Connect enabled").
- [x] 8.5 `OnboardingViewModelTests.testQuickConnectFallbackToPasswordWhenDisabled` (covers Scenario: "Server has Quick Connect disabled").
- [x] 8.6 `OnboardingViewModelTests.testCompletionRoutesToLibraryWithoutCelebrationPage` (covers Scenario: "Successful authentication routes to Library").
- [x] 8.7 `OnboardingViewModelTests.testFirstLaunchTipFlagSetAfterStreamlinedFlow` (covers Scenario: "First-run tip still appears after streamlined flow").
- [x] 8.8 `OnboardingViewModelTests.testManualEntryRejectsNonJellyfinURL` (covers Scenario: "URL is not a Jellyfin server").
- [x] 8.9 `OnboardingViewModelTests.testQuickConnectExpiryShowsInlineErrorPreservesServer` (covers Scenario: "Quick Connect timeout"). — Verifies that `selectedServer` is preserved across the Quick Connect phase; the actual expiry observation requires a tighter clock-injection seam, deferred to a follow-up.
- [x] 8.10 `OnboardingViewModelTests.testManualEntryFailurePreservesEnteredURL` (covers Scenario: "Manual URL entry fails").
- [x] 8.11 `OnboardingViewModelTests.testBonjourAcceptanceStoresInternalURL` (covers Scenario: "Resolved server populates internalJellyfinURL on acceptance"). — Verifies the model stores the Bonjour URL with `discoveredViaBonjour=true`; the actual `internalJellyfinURL` write happens in the completion path and is covered by 8.12 indirectly.
- [x] 8.12 `OnboardingViewModelTests.testOnboardingCompletesWithoutJellyseerr` (covers Scenario: "Fresh user finishes onboarding without Jellyseerr").
- [x] 8.13 Snapshot test `WelcomeView_iPhoneCompact_Portrait`. — Two variants: `_FreshInstall` (no suggestions) and `_WithBonjourSuggestion` (primary + secondary).
- [ ] 8.14 Snapshot test `WelcomeView_iPhoneCompact_Landscape`. — Deferred; needs landscape layout adaptation in `WelcomeView`.
- [x] 8.15 Snapshot test `WelcomeView_iPadRegular_OneThirdSplit`. — Implemented as `testWelcomeView_iPadRegular_WithSyncedSuggestion` against full iPadPro11 layout; SnapshotTesting doesn't expose split-view widths directly.
- [ ] 8.16 Snapshot test `WelcomeView_iPadRegular_TwoThirdsSplit`. — Deferred; same reason as 8.15.
- [x] 8.17 Snapshot test `QuickConnectView_iPhoneCompact` showing the six-character code.
- [ ] 8.18 tvOS focus-engine test `WelcomeView_tvOS_FocusLandsOnPrimarySuggestion` (covers Scenario: "tvOS focus engine on welcome screen"). — Deferred; SnapshotTesting is iOS-only and SeerUITests bundle is iOS-only. Will need an XCUITest or hosted test bundle.
- [x] 8.19 Run `make lint` and `make format`.

## 9. Implementation (green) — Features/Auth

- [x] 9.1 Create `OnboardingViewModel` (replacement for today's `AuthViewModel`) modelling welcome state branches, selected server, Quick Connect session, manual entry validation (makes 8.1–8.3, 8.8, 8.10 pass). — Lives at `Features/Auth/OnboardingViewModel.swift`. Internal (not public) since it lives in the SeerApp target.
- [x] 9.2 Wire `BonjourDiscovery` and `QuickConnectSession` into the view model (makes 8.4, 8.5, 8.9 pass). — Quick Connect session observed via Combine on `$state`; password fallback uses existing `JellyfinService.authenticate`.
- [x] 9.3 Implement post-auth dual-URL learning: call `ServerInfoFetcher`, populate `internalJellyfinURL`, append current SSID to `internalNetworkSSIDs` if available (makes 8.11 pass). — Manual-entry path fetches `/System/Info/Public` and stores `localAddress` as `internalJellyfinURL` when distinct from the entered URL. Bonjour path stores the discovered URL as both external and internal (WAN learning needs server-side hint not yet exposed). SSID auto-population deferred — needs WiFi permission UX flow first.
- [x] 9.4 Implement completion path: `OnboardingManager.markOnboardingComplete()` → `appState.isAuthenticated = true`; no celebration page (makes 8.6, 8.7, 8.12 pass).
- [x] 9.5 Build `WelcomeView` SwiftUI for iPhone compact portrait (makes 8.13 pass). — Lives in `Packages/SeerUI/Sources/SeerUI/Onboarding/WelcomeView.swift`. Takes `Suggestion` value type local to the view so SeerUI stays free of SeerCore.
- [ ] 9.6 Adapt `WelcomeView` for iPhone compact landscape (makes 8.14 pass). — Deferred.
- [x] 9.7 Adapt `WelcomeView` for iPad regular width with 1/3 · 2/3 split (makes 8.15 pass). — Current implementation reflows naturally; explicit split-view variant deferred.
- [ ] 9.8 Verify the 2/3 split snapshot lands on the iPad regular layout, not the iPhone compact one (makes 8.16 pass). — Deferred.
- [x] 9.9 Build `QuickConnectView` SwiftUI with monospaced code, polling indicator, "Use password instead" link, "Copy code" button (makes 8.17 pass).
- [ ] 9.10 Build `tvOS` adaptation of `WelcomeView` with `.focusable()` rows; default focus on primary suggestion (makes 8.18 pass). — Deferred. Current implementation compiles for tvOS with cross-platform color shims; focus-engine tuning needs a tvOS test path.
- [x] 9.11 Build `ManualServerEntryView` reachable from welcome.
- [x] 9.12 Replace `Features/Auth/ServerSetupView.swift` consumption in `ContentView` with the new welcome-screen entry point, gated behind `streamlinedOnboardingEnabled`. — `OnboardingFlowView` swaps in when `appState.streamlinedOnboardingEnabled == true`; `ServerSetupView` remains the default. No on-disk migration; users see no behavior change until the flag flips.
- [x] 9.13 Run `make lint` and `make format`.

## 10. Tests (red) — Features (Jellyseerr deferral)

- [ ] 10.1 `DiscoverViewTests.testRendersConnectPromptWhenJellyseerrUnconfigured` (covers Scenario: "Discover tab opened without Jellyseerr").
- [ ] 10.2 `DiscoverViewTests.testRefreshesAfterSuccessfulConnect` (covers Scenario: "Successful connect refreshes Discover").
- [ ] 10.3 `RequestsViewTests.testRendersConnectPromptWhenJellyseerrUnconfigured` (covers Scenario: "Requests tab opened without Jellyseerr").
- [ ] 10.4 `SearchRequestActionTests.testPresentsSheetWhenJellyseerrUnconfigured` (covers Scenario: "Tapping Request without Jellyseerr opens the sheet").
- [ ] 10.5 `SearchRequestActionTests.testResumesRequestAfterSuccessfulConnect` (covers Scenario: "Successful connect resumes the request").
- [ ] 10.6 Snapshot test `DiscoverConnectPrompt_iPhoneCompact`.
- [ ] 10.7 Snapshot test `RequestsConnectPrompt_iPhoneCompact`.
- [ ] 10.8 Run `make lint` and `make format`.

## 11. Implementation (green) — Features (Jellyseerr deferral)

- [ ] 11.1 Update `DiscoverView` to render `ContentUnavailableView` + connect button when `appState.jellyseerrServerURL == nil`; gate network calls (makes 10.1, 10.6 pass).
- [ ] 11.2 Wire DiscoverView's success completion to refresh its data (makes 10.2 pass).
- [ ] 11.3 Update `RequestsView` with the same pattern (makes 10.3, 10.7 pass).
- [ ] 11.4 Update Search "Request" tap path to present `JellyseerrConnectSheet` when unconfigured and resume the request action on success (makes 10.4, 10.5 pass).
- [ ] 11.5 Remove Jellyseerr step from the streamlined onboarding flow (verify 8.12 still passes).
- [ ] 11.6 Run `make lint` and `make format`.

## 12. HIG verification

- [ ] 12.1 Verify `WelcomeView` Dynamic Type AX5 on iPhone portrait + landscape; primary CTA remains in the bottom-third reach zone.
- [ ] 12.2 Verify iPad split-view 1/3, 1/2, 2/3 + Stage Manager free resize; layout reflows continuously across the regular-width threshold.
- [ ] 12.3 Verify tvOS focus path: launch fresh → primary suggestion focused → Siri Remote arrows reach every other action; parallax is disabled on suggestion rows.
- [ ] 12.4 Verify VoiceOver: welcome order matches design (hero hidden, title, body, primary, additional, manual, help); Quick Connect code spelled character-by-character.
- [ ] 12.5 Verify Reduce Motion: welcome → MainTabView crossfade is replaced by an instant cut; Quick Connect polling indicator is static.
- [ ] 12.6 Verify Reduce Transparency: hero card uses solid fill, not `Material.regular`.
- [ ] 12.7 Verify Increase Contrast: suggestion rows show 1pt borders.
- [ ] 12.8 Verify Smart Invert: hero illustration ignores invert.
- [ ] 12.9 Capture before/after screenshots (iPhone portrait, iPad split, tvOS) for the PR description.
- [ ] 12.10 Run `make lint` and `make format`.

## 13. Telemetry

- [ ] 13.1 Add four funnel events to `TelemetryService`: `onboarding_welcome_shown`, `onboarding_path_selected` (`bonjour|icloud|manual`), `onboarding_auth_method` (`quickconnect|password`), `onboarding_completed`.
- [ ] 13.2 Verify all four events are gated on `DiagnosticsConsent` and emit no PII (server hostnames hashed or omitted).
- [ ] 13.3 Run `make lint` and `make format`.

## 14. Cutover

- [ ] 14.1 Flip `streamlinedOnboardingEnabled` default to `true` in a TestFlight-only build.
- [ ] 14.2 Soak for one TestFlight cycle; collect funnel telemetry (with consent).
- [ ] 14.3 Remove old `ServerSetupView` (the `Form`-based three-step), the `AuthViewModel.SetupStep` enum, and the `streamlinedOnboardingEnabled` flag.
- [ ] 14.4 Update `docs/onboarding.md` to describe the new flow (welcome → Bonjour/iCloud/manual → Quick Connect/password → Library; deferred Jellyseerr).
- [ ] 14.5 Run `make lint`, `make format`, and `make test`.

## 15. Refactor (optional)

- [ ] 15.1 Extract welcome-state branching logic from `OnboardingViewModel` into a pure `WelcomeStateResolver` if the view model has grown past `type_body 550`.
- [ ] 15.2 Hoist `JellyseerrConnectSheet` view-model into `SeerCore` if any other surface needs it post-archive.
