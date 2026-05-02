## Context

The existing first-run flow (`Features/Auth/ServerSetupView.swift` +
`AuthViewModel.swift`) is a `Form`-based three-step ceremony: Jellyfin
credentials, Jellyseerr credentials, "Setup Complete" celebration. It
treats every launch identically and ignores three pieces of context that
already exist in the codebase or are freely available from the system:

- `ServerConfiguration` already models a dual-URL server
  (`internalJellyfinURL`, `internalNetworkSSIDs`) and `ServerURLResolver`
  already switches between them by SSID match. None of this is exercised
  during onboarding.
- The wrapped `jellyfin-sdk-swift` (Packages/JellyfinClient depends on
  `JellyfinAPI` from github.com/jellyfin/jellyfin-sdk-swift) ships
  `InitiateQuickConnectAPI`, `GetQuickConnectStateAPI`, and
  `AuthenticateWithQuickConnectAPI` — Quick Connect is one wiring job away.
- iOS Bonjour browse via `Network.framework`'s `NWBrowser` can discover
  Jellyfin servers advertising `_jellyfin._tcp` on the current Wi-Fi.

Constraints:

- iOS 26.0+ / tvOS 26.0+, Swift 6.2, SwiftUI.
- Dependency direction is one-way: features → clients → SeerCore. Bonjour
  and Quick Connect MUST live in `JellyfinClient`.
- `OnboardingManager.markOnboardingComplete()` and `What's New` gating
  must remain intact — they live in the App target and can't move.
- iCloud sync of `ServerConfiguration` already works; new code must keep
  the model wire-format stable (no schema migration).

Stakeholder pain (from the original exploration):

- Fresh user has to know their server URL by heart.
- Password entry on a phone keyboard.
- Jellyseerr API key requires admin access most viewers do not have.
- App breaks when the user moves from home Wi-Fi to cellular.

## Goals / Non-Goals

**Goals:**

- Reduce first-run typing to "tap a discovered server, approve a code in a
  browser, done" on the happy path.
- Make the welcome screen state-aware: a new device on an existing iCloud
  account, a fresh user on home Wi-Fi, and a truly cold install all see
  different primary suggestions.
- Automatically populate both internal and external URLs on a new
  `ServerConfiguration` so subsequent context switches (LAN ↔ WAN) just
  work.
- Defer Jellyseerr to on-demand prompts on Discover / Search / Requests so
  it stops blocking access to Jellyfin content.
- Keep the manual URL entry path always one tap away.

**Non-Goals:**

- Not replacing Jellyseerr's API-key auth model with OIDC. That's
  meaningful work that belongs in its own change.
- Not changing the on-disk schema of `ServerConfiguration`.
- Not introducing analytics beyond the existing OpenTelemetry funnel
  events that already gate on `DiagnosticsConsent`.
- Not redesigning `ServerEditView` or post-onboarding server management.
- Not adding a "demo server" or guest mode.

## Decisions

### D1. Bonjour discovery lives in JellyfinClient

`BonjourDiscovery` is an `@MainActor` `ObservableObject` in
`Packages/JellyfinClient` wrapping `NWBrowser` for `_jellyfin._tcp`. It
publishes a `discoveredServers: [DiscoveredJellyfinServer]` array and a
`permissionDenied: Bool` flag. The welcome screen owns one instance for
its lifetime and stops it on dismiss.

*Alternative considered:* `MCNearbyServiceBrowser` from
`MultipeerConnectivity`. Rejected — that's a peer-to-peer API; Jellyfin
servers don't run a Multipeer advertiser. Also: `NWBrowser` is the modern
Apple-recommended primitive for Bonjour browsing.

*Alternative considered:* third-party `swift-bonjour` package. Rejected —
adds a SwiftPM dependency for ~200 lines we can write directly.

### D2. Quick Connect uses the SDK's typed endpoints, polls with backoff

`QuickConnectSession` in `Packages/JellyfinClient` wraps the four SDK
endpoints (`/Enabled`, `/Initiate`, `/Connect`, `/AuthenticateWith`)
behind a state machine: `pending(code, secret) → approved(token) |
expired | failed(Error) | cancelled`.

Polling cadence: 1s for the first 30 attempts, 3s thereafter, until a
terminal state. Server's default secret TTL is 600s; we stop at the
server's reported expiry or after 600s, whichever is first.

*Alternative considered:* WebSocket / server-side push for state changes.
Rejected — Jellyfin's Quick Connect is HTTP polling by design; building a
WebSocket path would be incompatible with most server configurations
behind reverse proxies.

*Alternative considered:* fixed 2s polling forever. Rejected — burns
cellular and server cycles when the user has tab-switched away to type the
code.

### D3. Dual-URL learning happens automatically after first auth

After a successful Jellyfin authentication, the auth view model calls
`/System/Info/Public` and reads `LocalAddress`. If we authenticated via a
Bonjour discovery, the URL the user authenticated against IS the LAN URL
— we then attempt to fetch the WAN URL from the response. If we
authenticated via a manually-typed URL, we read `LocalAddress` and
opportunistically probe it; on success we store it as `internalJellyfinURL`
and add the current SSID (if available) to `internalNetworkSSIDs`.

*Alternative considered:* defer dual-URL learning to a follow-up settings
prompt. Rejected — automatic capture during onboarding is the whole point;
delaying it means the second launch on cellular is broken.

### D4. ServerURLResolver gets a reachability fallback (not a replacement)

The existing SSID-match path stays. We add a probe fallback that runs only
when (a) `internalNetworkSSIDs` is non-empty, (b) `currentSSID` is nil
(location permission denied OR not on Wi-Fi at all). The probe issues a
1-second `HEAD /System/Info/Public` against `internalJellyfinURL` with
`URLSession.dataTask` and an explicit timeout; success → use internal,
failure → use external.

*Alternative considered:* ditch SSID matching entirely in favor of
reachability probes on every request. Rejected — adds latency to every
network call and would break the existing model. SSID-as-fast-path with
probe-as-fallback preserves existing behavior for users who granted
location permission.

*Alternative considered:* probe both URLs in parallel and pick the
faster. Rejected — sends 2× requests forever; SSID match is free when
available.

### D5. Manual entry uses the same destination as discovery

Manual entry is a sibling of Bonjour selection, not a wholly separate
flow. Both produce a `URL`; the auth view model treats them identically
from that point on. Validation = `HEAD /System/Info/Public` returns
Jellyfin's expected payload (we don't trust HTTP 200 alone).

### D6. Jellyseerr connect sheet lives in SeerUI, summoned from features

`JellyseerrConnectSheet` is a reusable SwiftUI view in
`Packages/SeerUI/Sources/SeerUI/Onboarding/`. It owns its own view model
that talks to `JellyseerrService.verifyAuth()` and `AppState`. Each
feature surface (Discover, Search, Requests) presents it via `.sheet(...)`
and observes a completion callback. On success, the calling view re-runs
its load.

Stretch: the search "Request" tap path captures the originating item id
in the sheet's completion so the request can resume automatically — but
that's a tasks.md item, not a design constraint.

### D7. No "Setup Complete" page

The auth completion handler dispatches `OnboardingManager.markOnboarding-
Complete()`, switches `appState.isAuthenticated = true`, and the
`ContentView` group transition does the rest. The Library tab's first-
launch tip carries the welcome message that the celebration page used to.

### D8. Pre-warm during Quick Connect wait is opportunistic

While polling Quick Connect state, we cannot make authenticated Jellyfin
calls. We CAN start `BonjourDiscovery` for additional servers (no-op for
this flow but warms the system), and we can defer pre-warm until the
access token arrives. After auth, while the welcome → MainTabView
transition animates (~0.3s), we kick off the Library list fetch on a
detached task. This is best-effort; Library renders its own loading state
if the pre-warm hasn't completed.

## HIG & Layout

### iPhone (compact width)

Welcome screen renders as a vertical stack: hero illustration (top
quarter), title + body (next quarter), then a list of suggestions
(remaining half). Manual entry sits below as a less-emphasized button.

- **Portrait**: as above. Suggestions list scrolls if discovered servers
  exceed three entries.
- **Landscape**: hero shrinks to a leading-aligned icon; title + body and
  suggestions list reflow into a two-column layout (`HStack` at
  `.horizontalSizeClass == .regular` width, but in compact width
  landscape we stack with a smaller hero).
- **Safe areas**: respect bottom safe area; the primary CTA hugs the safe
  area's bottom edge with 16pt padding (one-handed reach).
- **Dynamic Type AX5**: hero illustration shrinks; title and body keep
  scaling. Suggestion rows use `Label` so the icon scales with the text.
- **One-handed reach**: primary suggestion sits in the lower third of the
  screen; the navigation bar hosts only a Help link.

Quick Connect view is a single centered card: the six-character code
(huge, monospaced, AX-scaled), an explainer line, a "Copy code" button,
and an inline "Use password instead" link.

### iPad (regular width)

The welcome screen uses a 1/3 · 2/3 split: hero + branding on the
leading side, suggestions list on the trailing side. On split-view widths
1/3 and 1/2 it collapses back to the iPhone single-column layout. Stage
Manager resizable windows: layout reflows continuously between the
two presentations at the regular-width threshold.

Quick Connect view stays single-card centered; pointer hover reveals a
secondary state on the "Copy code" button.

### tvOS

Welcome screen is a horizontal poster: hero on the leading 40%, focusable
suggestion list on the trailing 60%. Default focus lands on the first
suggestion (or on the manual-entry button if no suggestions). Each
suggestion row uses tvOS `.focusable()` with parallax disabled (these are
not poster art; parallax would be inappropriate per HIG).

Quick Connect view: code centered, Siri Remote dismissal goes back to
welcome screen. The "Copy code" button is dropped on tvOS (no clipboard
target) and replaced with "Show again" (re-display in case the user
missed a digit).

The Bonjour browser runs the same on tvOS — Apple TV is on the same Wi-Fi
as the Jellyfin server in nearly all real configurations.

### Aspect ratios

- **Portrait (iPhone, iPad)**: standard layout above.
- **Landscape (iPhone)**: shrunken hero, single column.
- **Landscape (iPad / tvOS)**: 1/3 · 2/3 split.
- **External display (iPad)**: hero illustration scales; the suggestions
  column stays at a comfortable 480pt max width (don't stretch a list of
  three rows across a 27" display).

### Accessibility

- **VoiceOver order** on welcome: hero (decorative, hidden) → title →
  body → primary suggestion → additional suggestions → manual entry →
  Help link.
- **VoiceOver order** on Quick Connect: page title → spelled-out code
  ("4, 7, 3, 8, 1, 9") → instructional text → Copy code → Use password
  instead → Cancel.
- **Reduce Motion**: replace the welcome → MainTabView crossfade with an
  instant cut. Quick Connect's "polling…" indicator becomes a static
  circle instead of a rotating progress view.
- **Reduce Transparency**: the welcome screen's hero card uses a solid
  fill instead of `Material.regular`.
- **Increase Contrast**: suggestion rows gain a 1pt border.
- **Smart Invert**: hero illustration is marked
  `.accessibilityIgnoresInvertColors(true)` so brand color does not
  invert.
- **Dynamic Type**: every text element scales through AX5 without
  truncation; the Quick Connect code itself uses `.system(size: 56,
  design: .monospaced)` with `.dynamicTypeSize(.xLarge ... .accessibility5)`.

### HIG references

- Apple HIG → Foundations → "Onboarding"
  (https://developer.apple.com/design/human-interface-guidelines/onboarding)
  — informs "explain value before asking for input" and "respect
  established patterns over novelty".
- Apple HIG → Patterns → "Loading"
  (https://developer.apple.com/design/human-interface-guidelines/loading)
  — Quick Connect polling shows a determinate-feeling indicator with
  status text, not an indefinite spinner alone.
- Apple HIG → Inputs → "Sign in with Apple" sibling material on
  authentication patterns informs the "secondary path is always one tap
  away" rule (Quick Connect ↔ password swap).
- Apple HIG → Components → Lists and Tables — suggestions list uses
  standard list styling, not bespoke cells.
- Apple HIG → tvOS → Focus and selection — suggestion rows are
  individually focusable; the welcome hero is not.

## Risks / Trade-offs

- **[Risk] Local network permission prompt is jarring on first launch.**
  → Mitigation: present the welcome screen with manual entry first, and
  only start the Bonjour browser after a brief delay (or after the user
  taps a "Look for servers nearby" button on the first launch). Subsequent
  launches start the browser immediately.
- **[Risk] Quick Connect secret leaking via screen capture / shoulder
  surfing.** → Mitigation: the secret is never displayed; only the
  6-character code is shown to the user. The secret stays in memory until
  the exchange completes.
- **[Risk] Pre-warm fires after the user authenticates against a server
  that is reachable but slow to enumerate libraries — Library tab still
  spins.** → Mitigation: spec already states pre-warm is opportunistic
  and Library renders its own loading state. Document that pre-warm is a
  best-effort optimization, not a guarantee.
- **[Risk] Reachability fallback in `ServerURLResolver` adds 1s timeout
  to first request after a network change.** → Mitigation: probe runs
  once per (network change × server); cache the result for 60s keyed by
  network interface identifier.
- **[Risk] Bonjour discovers a server the user has no account on, leading
  to a confusing auth failure.** → Mitigation: surface the server's
  `ProductName` from `/System/Info/Public` after tap so the user sees
  "Jellyfin Server (Mac mini)" before being asked to authenticate.
- **[Risk] tvOS Local Network permission UI is more intrusive than iOS.**
  → Mitigation: same delayed-start pattern as iOS; on tvOS we can also
  show a "Tap Play to look for servers" hint to make the prompt feel
  earned.
- **[Risk] Existing tests for `AuthViewModel` break.** → Mitigation:
  rename today's coverage as the manual-entry path's coverage, add new
  test suites for `BonjourDiscovery`, `QuickConnectSession`, and welcome
  state branching.

## Migration Plan

No on-disk migration needed. Steps:

1. Land `BonjourDiscovery` and `QuickConnectSession` in `JellyfinClient`
   first (with tests). Not yet wired to UI.
2. Land `JellyseerrConnectSheet` in `SeerUI` (with tests). Wire to
   Discover, Search, Requests behind a runtime flag default-off so the
   existing onboarding still demands Jellyseerr.
3. Build the new welcome screen and Quick Connect view in `Features/Auth/`
   alongside the old `ServerSetupView` (different file). Gate routing in
   `ContentView` behind the same runtime flag.
4. Flip the flag default-on in a TestFlight-only build for one cycle.
5. Once validated, remove the old `ServerSetupView`, `Form`-based
   `AuthViewModel.SetupStep` enum, and the runtime flag in a follow-up
   PR.

Rollback: flip the runtime flag default back to off; the old
`ServerSetupView` is still present until step 5.

## Open Questions

- Should `ServerURLResolver`'s reachability probe also fire on the
  external URL when SSID matches? (Detect "I'm on home Wi-Fi but the LAN
  URL is broken" — e.g. router rebooting.) Trade-off: extra latency vs.
  resilience.
- For tvOS, do we want a QR code path (show QR on TV → scan with phone →
  phone holds creds → push to TV via Bonjour)? Out of scope here, but
  worth a separate exploration.
- Funnel telemetry events: name them now or in a follow-up? Suggest now,
  with the four canonical events: `onboarding_welcome_shown`,
  `onboarding_path_selected` (bonjour|icloud|manual),
  `onboarding_auth_method` (quickconnect|password),
  `onboarding_completed`.
- Localization: copy strings (welcome hero text, Quick Connect
  instructions, Jellyseerr CTA) — does the project have an existing
  Localizable.strings infrastructure to slot into, or do we ship English
  only initially?
