## Why

The current first-run experience drops a brand-new user onto a dense
three-step Form: Jellyfin URL + username + password, then Jellyseerr URL +
admin-issued API key, then a celebration screen. It assumes the user knows
their server URL by heart, has access to the Jellyseerr admin panel, and
wants to type passwords on a phone keyboard. It is identical on a fresh iCloud
account and on a brand-new device of an existing user, ignores Wi-Fi context
entirely, and never tells the user that the same server is reachable at two
URLs (LAN vs WAN). The data and SDK pieces to do better already exist —
`ServerConfiguration` already has `internalJellyfinURL` and
`internalNetworkSSIDs`, the wrapped Jellyfin SDK exposes Quick Connect
endpoints, and Jellyfin servers advertise themselves over Bonjour — they
are just not wired into onboarding.

```
   TODAY                                AFTER
   ─────────────────────────            ──────────────────────────────
   ┌─────────────────────┐              ┌──────────────────────────┐
   │ Step 1: Jellyfin    │              │  WELCOME (state-aware)   │
   │  URL  [_________]   │              │                          │
   │  User [_________]   │              │  • Sign back in to       │
   │  Pass [•••••••••]   │              │    <iCloud server>       │
   │  [Connect]          │              │  • Use <hostname>        │
   └─────────────────────┘              │    on this Wi-Fi         │
              ↓                         │  • Enter URL manually    │
   ┌─────────────────────┐              └────────────┬─────────────┘
   │ Step 2: Jellyseerr  │                           ↓
   │  URL  [_________]   │              ┌──────────────────────────┐
   │  Key  [•••••••••]   │              │  AUTHENTICATE            │
   │  [Connect] [Skip]   │              │   ┌──────────────┐       │
   └─────────────────────┘              │   │   4 7 3 8    │  ←──  │
              ↓                         │   │              │  Quick│
   ┌─────────────────────┐              │   │   1 9        │  Conn │
   │ Step 3: Setup       │              │   └──────────────┘       │
   │   Complete!  ✓ ✓    │              │   "Use password instead" │
   │   [Get Started]     │              └────────────┬─────────────┘
   └─────────────────────┘                           ↓
              ↓                         ┌──────────────────────────┐
            Library                     │  Library (pre-warmed)    │
                                        └──────────────────────────┘

                                        Jellyseerr deferred to
                                        Discover/Search/Requests CTAs
```

## What Changes

- **State-aware welcome screen** replaces today's bare Form. Branches on
  startup state: re-auth a server already in iCloud, accept a Bonjour-
  discovered server on the current Wi-Fi, or fall back to manual URL entry.
- **Bonjour discovery** of `_jellyfin._tcp` services on the current network,
  surfaced as one-tap suggestions on the welcome screen.
- **Jellyfin Quick Connect** as the default authentication path when the
  server has it enabled. Falls back inline to username/password without a
  separate screen.
- **Automatic dual-URL learning**: after a successful authentication, the
  app fetches `/System/Info/Public` to learn the server's other URL
  (LAN ↔ WAN) and stores both on `ServerConfiguration`, automatically
  recording the current SSID into `internalNetworkSSIDs` when entering on
  Wi-Fi.

```
   THE TWO-URL REALITY (already in ServerConfiguration; just not used)
   ───────────────────────────────────────────────────────────────────

       At home (Wi-Fi)                   Away (cellular / other Wi-Fi)
            │                                       │
            ▼                                       ▼
       ┌─────────┐                             ┌─────────┐
       │ iPhone  │                             │ iPhone  │
       └────┬────┘                             └────┬────┘
            │ http://192.168.1.10:8096              │ https://media.example.com
            │ ⚡  fast LAN, no TLS                   │ 🌐 works anywhere
            ▼                                       ▼
       ┌──────────────────────────────────────────────────┐
       │             Jellyfin server                      │
       │  /System/Info/Public exposes both addresses      │
       └──────────────────────────────────────────────────┘

   Onboarding learns BOTH after first auth.
   ServerURLResolver picks per request: SSID match → fast path,
   reachability probe → fallback when location permission denied.
```
- **Deferred Jellyseerr connect**: Jellyseerr is removed from the front-door
  flow. The Discover tab, Search "Request" button, and Requests tab each
  surface a connect-on-demand CTA when Jellyseerr is not configured. The
  paste-API-key form moves into a reusable sheet summoned from those CTAs.

```
   JELLYSEERR DEFERRAL — three on-demand touchpoints
   ──────────────────────────────────────────────────────────

   ┌─────────────────────────┐  ┌─────────────────────────┐
   │ Discover tab            │  │ Requests tab            │
   │ (no Jellyseerr config)  │  │ (no Jellyseerr config)  │
   │                         │  │                         │
   │  ContentUnavailableView │  │  ContentUnavailableView │
   │  "Discover Movies &     │  │  "Manage Requests"      │
   │   Shows"                │  │  [Connect Jellyseerr]   │
   │  [Connect Jellyseerr] ──┼──┼──┐                      │
   └─────────────────────────┘  └──┼──────────────────────┘
                                   ▼
                            ┌──────────────────────┐
   ┌─────────────────────┐  │  JellyseerrConnect   │
   │ Search → "Request"  │  │  Sheet (SeerUI)      │
   │ tap on a result   ──┼──▶                      │
   │ when not configured │  │   URL    [_______]   │
   └─────────────────────┘  │   API    [•••••••]   │
                            │   [Connect] [Later]  │
                            └──────────┬───────────┘
                                       │
                                       ▼
                            On success: persist creds,
                            refresh caller, resume the
                            originating action (request).
```
- **Setup-complete celebration page is dropped**. After authentication the
  user goes straight into the Library tab; the library grid loading is the
  celebration. Library cache is pre-warmed during the Quick Connect polling
  step.
- **BREAKING (UX only, no on-disk schema change)**: existing
  `ServerSetupView` flow is replaced. `OnboardingManager.markOnboarding-
  Complete()` is still called at the same logical point, so What's New and
  first-run-tip behavior are preserved.

## Capabilities

### New Capabilities

- `server-onboarding`: state-aware first-run welcome screen and orchestration
  across the discovery / Quick Connect / manual entry paths through to the
  Library tab. Owns the `ServerSetupView` replacement.
- `local-server-discovery`: Bonjour/mDNS browse for Jellyfin servers on the
  current network, exposed as a published list of discovered hosts. Lives
  in `JellyfinClient` so it can be reused outside onboarding (e.g. "Add
  another server").
- `quick-connect-auth`: Jellyfin Quick Connect session — initiate, poll,
  authenticate. Lives in `JellyfinClient` wrapping the SDK's
  `InitiateQuickConnect`, `GetQuickConnectState`, and
  `AuthenticateWithQuickConnect` endpoints. Reusable for re-auth flows.
- `jellyseerr-on-demand`: connect-on-demand pattern surfaced from
  `DiscoverView`, search "Request" button, and `RequestsView` empty state.
  Hoists today's paste-the-API-key form into a sheet reachable from any
  feature surface.

### Modified Capabilities

(None. There are no existing specs in `openspec/specs/` — this proposal
introduces the first specs in those areas.)

## Impact

**Affected code (new and modified):**

- `Features/Auth/` — `ServerSetupView` and `AuthViewModel` are largely
  rewritten. New `WelcomeView`, `QuickConnectView`, `ManualServerEntryView`
  child views.
- `App/SeerApp/Onboarding/OnboardingManager.swift` — unchanged surface;
  new welcome screen calls the same `markOnboardingComplete()`.
- `Packages/JellyfinClient/Sources/JellyfinClient/` — new
  `BonjourDiscovery` (uses `Network.framework` `NWBrowser`),
  `QuickConnectSession` (wraps SDK Quick Connect endpoints),
  extension on `JellyfinService` to expose `/System/Info/Public`.
- `Packages/SeerCore/Sources/SeerCore/Models/ServerConfiguration.swift` —
  no schema change. New populated fields on insert come from the auth
  flow; existing servers are unaffected.
- `Packages/SeerCore/Sources/SeerCore/Services/ServerURLResolver.swift` —
  reachability-fallback added when location permission is denied so
  `internalNetworkSSIDs` is no longer the only switch.
- `Features/Discover/`, `Features/Search/`, `Features/Requests/` — each
  gets a `JellyseerrConnectPromptView` (new, in `SeerUI`) shown when
  `appState.jellyseerrServerURL == nil`.
- `Packages/SeerUI/Sources/SeerUI/` — new reusable components:
  `WelcomeHeroView`, `QuickConnectCodeView`, `JellyseerrConnectSheet`.

**Platforms:** iOS first. tvOS adaptations are scoped in (Quick Connect is
the natural tvOS auth path; Bonjour works; welcome layout uses the focus
engine instead of taps).

**Dependencies:** No new SwiftPM packages. `Network.framework` for
`NWBrowser` ships with the SDK. The wrapped `jellyfin-sdk-swift` already
ships Quick Connect.

**Privacy:** Bonjour browse on iOS requires `NSLocalNetworkUsageDescription`
in `Info.plist` and `NSBonjourServices` declaring `_jellyfin._tcp`. New
permission prompt copy needed.

**Telemetry:** Onboarding funnel events (welcome → path chosen → auth method
→ completion) gated on `DiagnosticsConsent` — same opt-in path as the rest
of the app.

**Migration:** None on disk. Users with existing servers skip the welcome
screen and go straight into the app as today.
