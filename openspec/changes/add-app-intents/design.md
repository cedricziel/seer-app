## Context

Seer ships zero App Intents today. There is no URL scheme, no Spotlight
integration, no donation of `INPlayMediaIntent`, and no AppShortcutsProvider.
The verb-shaped operations (request, search, resume, mark watched, download)
all live behind ViewModels in the SeerApp target and require an unlock-app-
tap-tap-tap path to invoke.

What already exists and shapes this design:

- `OfflineSync` keeps a SwiftData mirror of the user's libraries
  (`CachedLibrary`, `CachedMediaItem`, `CachedUserProgress`). This is the
  right query surface for AppEntity providers — it is local, it is fast,
  and it survives offline.
- `AppState` (in `SeerCore`) owns auth state, multi-server config, and
  Keychain access through `KeychainManager`. App Intents will call the same
  `AppState` the rest of the app does.
- Services are constructed on demand by ViewModels today
  (`JellyfinService`, `JellyseerrService`, `PlaybackService`). Intents
  follow the same pattern: an intent's `perform()` instantiates the
  service it needs, reads credentials from `AppState`, and goes.
- `DiagnosticsConsent` is the project's established opt-in pattern for
  any data leaving the app's process. Spotlight semantic indexing is the
  same shape (data leaves the app's sandbox into the system index), so
  this design reuses the pattern with a sibling
  `appIntentsIndexingEnabled` flag.

Constraints:

- iOS 26.0+, Swift 6.2, SwiftUI. iOS 18+ AssistantSchemas are trivially
  available.
- Dependency direction stays features → clients → SeerCore.
  AppEntities and intents live in SeerCore (cross-cutting, no UI) except
  for `AppShortcutsProvider` and `SeerFocusFilter` which must live in the
  app target.
- App Intents `perform()` runs in the host app process for foreground
  intents, but Spotlight indexing and entity queries can run out-of-process.
  Keychain access via `KeychainManager` already uses an access group
  (`$(AppIdentifierPrefix)com.cedricziel.seer`) that works across the
  app and any future intents extension; we keep that posture.
- iOS only for v1. tvOS App Intents are scoped out.

## Goals / Non-Goals

**Goals:**

- Surface Seer's three highest-value verbs (request, search, resume) as
  App Shortcuts that auto-appear in Spotlight, Siri, and the Action Button.
- Provide a complete set of Tier 2 intents for power-user automation
  (request status, offline download, mark watched).
- Plug into iOS 18+ system surfaces correctly (AssistantSchemas, Focus
  Filters, `INPlayMediaIntent` donation) rather than reinventing them.
- Make the `OfflineSync` cache load-bearing for AppEntity queries so
  intents are instant and offline-tolerant.
- Treat Spotlight semantic indexing as user data and gate it behind an
  opt-in setting consistent with `DiagnosticsConsent`.

**Non-Goals:**

- Not building a comprehensive deep-link routing layer. We register
  the `flowmark://` URL scheme and define the minimum set of routes
  intents need (`flowmark://media/<id>`, `flowmark://library`); a
  broader URL routing surface (server-switching, settings deep links,
  share-extension targets) belongs in a separate change.
- Not building an Intents Extension. App Intents in iOS 16+ run in the
  host app for the surfaces we ship; an extension is only needed for
  Watch/Lock-screen widget surfaces we are not targeting.
- Not adding any new telemetry. Voice and system-dispatched actions are
  inherently intimate; we do not log intent invocations even with consent.
- Not exposing the entire library to Spotlight. Indexed payload is title,
  year, type, identifier. No posters, no plot summaries, no watched state.
- Not adding tvOS App Intents support. Separate change later if demand
  surfaces.
- Not changing any existing ViewModel APIs. Intents construct the same
  services and call the same methods ViewModels do today.

## Decisions

### D1. AppEntity types live in SeerCore, queries route through OfflineSync

`MediaItemEntity`, `RequestEntity`, and `ServerEntity` are defined in
`Packages/SeerCore/Sources/SeerCore/AppIntents/`. `MediaItemEntity` and
`RequestEntity` conform to `IndexedEntity` so the system can semantic-index
them. Their `EntityQuery` types read directly from the `OfflineSync`
SwiftData store via existing `@Query`-friendly fetch descriptors —
`CachedMediaItem` and (a new) `CachedRequest` model.

*Alternative considered:* live network reads in entity queries. Rejected
— intents must feel instant. Voice queries that take 2 seconds to return
candidates feel broken. Stale-but-fast wins.

*Alternative considered:* defining entities in a new `AppIntents` package.
Rejected — every Feature already depends on `SeerCore`, and the entity
types reference SwiftData models that already live there. New package
buys nothing.

### D2. AppShortcutsProvider lives in the app target

`SeerAppShortcutsProvider` is in `App/SeerApp/AppIntents/`. The framework
discovers `AppShortcutsProvider` at the main bundle level — it cannot
live in a SwiftPM package. The provider registers Tier 1 intents only;
Tier 2 intents are still callable via Shortcuts but are not given a fixed
voice phrase or Spotlight slot.

### D3. Multi-server resolution is "hybrid": param defaults to active server

Every intent that touches a Jellyfin or Jellyseerr server takes an
optional `ServerEntity` parameter. Resolution rules:

1. If the user supplied a server in their Shortcut configuration, use it.
2. If only one server is configured, use it (no disambiguation needed).
3. Otherwise default to `AppState.activeServer`.

This makes voice usage feel natural for the single-server case (the vast
majority) without losing per-shortcut control for the multi-server case.

*Alternative considered:* always require a server param. Rejected — adds
ceremony for the 90% case ("which server? — Personal" is annoying every
time).

*Alternative considered:* always silently use active server. Rejected —
breaks for users who have a Shortcut "Request on Family server" and
expect that to override the currently-active server.

### D4. RequestMediaIntent does NOT bypass Jellyseerr permissions

The intent calls the same `JellyseerrService.createRequest` path the
Search "Request" button calls today. If the user's Jellyseerr account is
not configured for auto-approval, the request lands in pending state on
the server, exactly as the in-app flow would. No new policy is added.

The intent's result snippet reflects what happened: "Requested" vs
"Request submitted, pending admin approval".

### D5. Spotlight semantic indexing is opt-in, per-device, defaults off

A new `appIntentsIndexingEnabled` flag on `AppState` gates calls to
`CSSearchableIndex`. The flag is `UserDefaults.standard`-backed and
**per-device** — it is NOT mirrored to iCloud KVS. The flag is exposed
in `Features/Feedback/PrivacySettingsView` as a toggle next to the
existing diagnostics controls.

Per-device persistence matches both the existing project pattern
(`DiagnosticsConsent` is `UserDefaults.standard` only — see
`Packages/SeerCore/Sources/SeerCore/Services/DiagnosticsConsent.swift`)
AND the technical reality: `CSSearchableIndex` is itself device-local,
so a synced flag would govern a per-device effect, which is a
nonsense pairing. Concretely, this means a user can enable indexing
on their personal iPhone and leave it off on a shared family iPad
without round-trips through iCloud.

When indexing is on, we register a single index transaction at app
launch and after each `OfflineSync` refresh, deleting the previous
batch and adding the current cached items.

When indexing is off, no items are registered, and any previously-
registered items are deleted on the first launch after the flag flips.

*Alternative considered:* default the flag on, since the data is local-
to-device. Rejected — Seer's existing privacy stance is opt-in for
anything system-visible, and Spotlight semantic index does cross the
app sandbox into system surfaces (lock screen suggestions, Apple
Intelligence). Keeping the bar consistent matters more than the modest
discoverability gain.

*Alternative considered:* mirror the flag to iCloud KVS for cross-
device convenience. Rejected — the index itself does not sync, so
mirroring the flag implies a guarantee the system cannot keep
("turned on everywhere" but the iPad still shows nothing until that
device's `OfflineSync` runs and indexes). Per-device intent matches
per-device effect.

### D6. INPlayMediaIntent donation, not a custom PlayMediaIntent

`PlaybackClient` donates an `INPlayMediaIntent` after every successful
playback start, populated with the `MediaItemEntity` and a
`UIImage`-backed thumbnail. Donation goes through `INInteraction.donate()`
on the playback success path.

This gives the system the right hook for "Hey Siri, play X again" without
us authoring a custom intent that competes with the built-in
`MediaPlayer.framework` integration. We do NOT publish a custom
`PlayMediaIntent`; the built-in plumbing is better than anything we'd
write.

*Alternative considered:* expose our own `PlayMediaIntent`. Rejected —
custom play intents have to handle audio session, background playback,
and Now Playing wiring already done by the system intent. Donating the
built-in one is strictly better.

### D7. ResumeWatchingIntent has no parameters and opens the app

`ResumeWatchingIntent.perform()` resolves the most recent
`CachedUserProgress` with `playbackPositionTicks > 0`, picks the
associated `CachedMediaItem`, and returns an `OpensIntent` with a
deep-link target `flowmark://media/<id>`. The `flowmark://` URL scheme
is registered in `Info.plist` (matching the App Store listing brand
"Flowmark Media", not the engineering bundle name "Seer") and handled
by `ContentView`'s `onOpenURL`.

Routes defined in this change:

- `flowmark://media/<id>` — open the player or detail view for the
  given `MediaItem.id` on the active server.
- `flowmark://library` — open the Library tab.

If no in-progress item exists, the intent returns a result snippet
"Nothing to resume yet" and opens `flowmark://library`.

*Alternative considered:* play immediately in the background. Rejected
— playback requires a video surface; surfacing it as an audio-only
intent would be misleading. Opening the app to the player is the honest
behavior.

*Alternative considered:* keep the scheme private (no `Info.plist`
registration). Rejected — App Intents' `OpensIntent` requires a real
URL the system can dispatch, and the user-facing brand "Flowmark
Media" lacks any URL scheme today. Registering it now buys system
dispatch correctness and unlocks future deep-link work behind the
same scheme.

### D8. SearchMediaIntent returns AppEntities, conforms to .media.search

`SearchMediaIntent` returns `[MediaItemEntity]` and conforms to
`AssistantSchemas.Media.search` (iOS 18+). Behavior:

1. Hit the `OfflineSync` cache for fast local matches.
2. If the result count is below a threshold (3) AND we are online AND
   the user has a Jellyseerr server configured, also issue a Jellyseerr
   discovery search; merge results, deduplicating by external IDs (TMDB).
3. Return up to 10 entities ordered by local-first, then external.

The `.media.search` schema lets Apple Intelligence and the system search
include Seer results inline alongside Music, Podcasts, and Apple TV.

### D9. Focus Filter pins the active server

`SeerFocusFilter` conforms to `SetFocusFilterIntent` with one parameter:
a `ServerEntity`. When a Focus mode with the filter activates,
`AppState.activeServerID` is set to the filter's server until the Focus
deactivates, at which point we restore the previous active server.

This is the one place where Seer's multi-server complexity becomes a
feature rather than a tax: "Family Movie Night" focus pins the family
Jellyfin server; the Spotlight index, the Resume intent, and the
discovery search all follow.

*Alternative considered:* expose all servers in the filter so the user
can pick "show only these libraries". Rejected — too granular for v1.
Server-scope is the unit users already think in.

### D10. Not-signed-in fallback throws IntentError.needsConfiguration

Every intent's `perform()` checks `appState.isAuthenticated` first. If
false, it throws `IntentError.needsConfiguration` (a new
`LocalizedError + AppIntentError` we define) which the system surfaces
as a "Set up Seer to use this shortcut" message and offers an "Open Seer"
button that lands the user on onboarding.

This matches today's first-launch behavior exactly — the intent does
not pretend to work for an unauthenticated user.

## HIG & Layout

App Intents are mostly system-rendered surfaces. The user-facing UI we
do author falls into three buckets: intent dialog snippets (custom
`SwiftUI` views shown inline by Siri/Shortcuts), App Shortcut titles +
parameter summaries (text and SF Symbols), and the privacy settings
toggle for Spotlight indexing.

### iPhone (compact width)

- **Intent dialog snippets** — when an intent returns a result with a
  custom view, render with a single-line title + supporting subtitle in
  Dynamic Type body, framed in a system-grouped background. The whole
  snippet honors the system-dictated max height (iOS clips inline
  snippets to ~120pt).
- **Privacy settings toggle** — `Toggle("Index for Spotlight & Siri",
  isOn: $indexingEnabled)` rendered in the existing
  `PrivacySettingsView` Form. Description footer text spells out what
  is indexed (title, year, type — no posters, no watched state).
- **Portrait + Landscape**: both use the system-rendered surfaces
  unmodified. Snippet views are designed to fit in the system's compact
  container in either orientation.
- **Dynamic Type AX5**: snippet views use only `.body` and `.headline`
  text styles; no fixed sizes. SF Symbols scale via `.imageScale(.large)`
  with no hard-coded dimensions.

### iPad (regular width)

- Inline intent snippets render slightly wider on iPad's Siri surface
  but use the same single-column layout. No iPad-specific adaptation
  needed.
- Privacy settings sit in the same Form layout, automatically inheriting
  iPad's grouped-list formatting.
- Split-view 1/3, 1/2, 2/3 — all unaffected; settings reflow naturally
  with iPadOS Form rendering.

### tvOS

N/A — iOS only for v1. Per Decision: tvOS adaptations of any of these
intents are scoped to a separate change.

### Aspect ratios

System-rendered surfaces handle all aspect ratios. The privacy settings
toggle uses standard Form rendering and reflows automatically.

### Accessibility

- **VoiceOver**: snippet views use `.accessibilityElement(children:
  .combine)` so VoiceOver reads "Requested The Bear" as one element
  rather than four. Privacy toggle inherits the standard `Toggle`
  VoiceOver behavior with a description trait taken from the footer
  text.
- **Reduce Motion**: snippets do not animate. The system handles its
  own surface transitions and already honors the setting.
- **Reduce Transparency**: snippet backgrounds use solid system colors,
  not `Material`.
- **Increase Contrast**: snippet text uses `.foregroundStyle(.primary)`
  and `.secondary`; the system maps these to high-contrast palettes
  automatically.
- **Dynamic Type**: every text element scales through AX5; SF Symbols
  scale via image scale, not fixed sizes.

### HIG references

- Apple HIG → Technologies → "App Shortcuts"
  (https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)
  — informs the "five or fewer App Shortcuts" rule (we have three),
  the parameter summary phrasing pattern, and the SF Symbol pairing.
- Apple HIG → Technologies → "Siri"
  (https://developer.apple.com/design/human-interface-guidelines/siri)
  — "design intents around what users want to accomplish, not your
  app's UI." Our verb naming follows this: "Request", "Resume",
  "Search" — not "Open Discover Tab".
- Apple HIG → Patterns → "Onboarding" — Decision D10 (not-signed-in
  fallback) follows the "explain why before asking for setup" pattern.
- Apple HIG → Foundations → "Privacy"
  (https://developer.apple.com/design/human-interface-guidelines/privacy)
  — informs the opt-in default for Spotlight indexing.
- Apple HIG → Inputs → "Focus and Selection" — n/a for v1 (iOS only).

## Risks / Trade-offs

- **[Risk] OfflineSync cache may be empty on first intent invocation**
  (e.g., user installs Seer, says "Hey Siri, request The Bear" before
  ever opening it). → Mitigation: intents check
  `appState.isAuthenticated` first and throw `needsConfiguration` if
  false. If authenticated but cache is empty, `RequestMediaIntent` still
  works (it does not need the cache; it queries Jellyseerr discover by
  title); `SearchMediaIntent` and `ResumeWatchingIntent` return a
  graceful "No results yet" snippet.
- **[Risk] Spotlight index drift** — cache changes faster than we
  re-index. → Mitigation: re-index on every `OfflineSync` refresh
  (already a known checkpoint). Acceptable staleness window: until the
  next library refresh.
- **[Risk] Donating INPlayMediaIntent for Live TV / non-resumable
  content surfaces broken "play again" suggestions.** → Mitigation:
  donation is gated on `MediaItem.isResumable` (already on the model);
  Live TV streams skip donation.
- **[Risk] Multi-server hybrid resolution surprises users with
  "wrong server" results when the active server is not the one they
  meant.** → Mitigation: the intent's result snippet includes the
  server name in the subtitle when more than one server is configured
  ("Requested on Personal • The Bear"). Visible disambiguation rather
  than silent default.
- **[Risk] AssistantSchema conformance binds us to Apple's evolving
  schema definitions.** → Mitigation: only `SearchMediaIntent` conforms;
  if the schema changes incompatibly we drop conformance and keep the
  custom intent. Tier 1 + Tier 2 do not depend on AssistantSchema.
- **[Risk] App Intents in SeerCore make SeerCore depend on
  AppIntents.framework.** → Mitigation: AppIntents is a system framework
  and is available on every supported platform (iOS 16+, macOS 13+);
  no extra dependency is added.
- **[Risk] Voice request for a movie that is already in the user's
  library produces a confusing "request" — they own it.** → Mitigation:
  `RequestMediaIntent` first checks the OfflineSync library cache by
  TMDB id; if found, returns "You already have <title>" snippet
  without contacting Jellyseerr.
- **[Risk] Focus Filter activates and the user has not configured the
  filter's server — silent breakage.** → Mitigation: filter's
  `IntentParameter<ServerEntity>` is required (not optional), so users
  must pick a server when configuring the Focus mode. If the chosen
  server is later deleted, `perform()` no-ops and logs to OS log.

## Migration Plan

No on-disk migration. All additions; nothing existing is removed or
renamed.

Steps:

1. Land `MediaItemEntity`, `RequestEntity`, `ServerEntity`, and their
   `EntityQuery` types in `SeerCore` (with tests).
2. Land the six intent types in `SeerCore` (with tests).
3. Land `SeerAppShortcutsProvider` in the app target, register the
   Tier 1 trio.
4. Land Spotlight indexing wired to `appIntentsIndexingEnabled` and
   the privacy settings toggle.
5. Land AssistantSchema conformance + `INPlayMediaIntent` donation.
6. Land Focus Filter.
7. Verify on-device: voice flow on iPhone, Spotlight surface, Action
   Button, Focus mode pinning.

Rollback: each step is independently revertible. The intents can be
removed by dropping the `AppShortcutsProvider` registration without
touching the entity types.

## Open Questions

- Should `ResumeWatchingIntent` ever play immediately when the device
  is connected to a HomePod / AirPlay 2 audio target? Voice-triggered
  playback to a paired audio surface is technically reasonable, but
  the implementation is a mess (we'd need to detect the route in the
  intent and gate visual surfacing accordingly). Defer to a v2.
- For `DownloadForOfflineIntent` driven by a Focus / shortcut
  automation, do we want a "Download all Continue Watching" macro
  alongside the per-item version? Useful for "before flight"
  automations but adds a second entity-list parameter shape. Lean
  toward shipping per-item only in v1 and adding the bulk variant
  later.
- Localization of App Shortcut phrases: `AppShortcutsProvider`
  surfaces phrases in user-locale. Does the project have an existing
  `Localizable.strings` infrastructure to slot into, or do we ship
  English-only phrases initially? (Project today is English-only.)
- Should Spotlight indexing be tied to `DiagnosticsConsent` directly
  (one switch covers all "data leaves the app" cases) or have its own
  setting (`appIntentsIndexingEnabled`)? Current design favors the
  latter for separable mental models, but a single switch is also
  defensible.
