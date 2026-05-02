## Why

Seer's verbs — request a movie, resume the show I was watching, search my
library — are precisely the kind of small, async, low-stakes operations that
voice and Shortcuts excel at, and the kind of operations users currently have
to unlock a phone, find an app, switch tabs, and tap their way to. The
Jellyseerr request flow in particular is a fire-and-forget action: hear about
a show, ask the system to request it, forget about it. There is no system
surface for that today.

The codebase already has the verb-shaped methods (`DiscoverViewModel.request-
Media`, `SearchViewModel.search`, `JellyfinService.getContinueWatching`,
`LibraryViewModel.markAsWatched`) and an offline cache (`OfflineSync`) that
can serve as a fast, network-free index for system queries. The missing
piece is the App Intents surface: AppEntities the system can index, intents
it can dispatch, and AppShortcuts it can auto-surface in Spotlight, Siri,
the Action Button, and Apple Intelligence.

```
   TODAY                              AFTER
   ─────────────────────────          ──────────────────────────────
   "I want to request The Bear"       "Hey Siri, request The Bear on Seer"
            ↓                                       ↓
       Unlock phone                        Done. Notification when ready.
            ↓
        Open Seer
            ↓
       Discover tab
            ↓
       Search "The Bear"
            ↓
       Tap result, tap Request
            ↓
       Tap confirm
            ↓
            Done.
```

```
   THREE TIERS, ONE SURFACE
   ──────────────────────────────────────────────────────────────

   Tier 1 — App Shortcuts (auto-surfaced in Spotlight, no setup)
   ┌─────────────────────────────────────────────────────────┐
   │  "Request <title> on Seer"     ← RequestMediaIntent     │
   │  "Search Seer for <title>"     ← SearchMediaIntent      │
   │  "Resume on Seer"              ← ResumeWatchingIntent   │
   └─────────────────────────────────────────────────────────┘

   Tier 2 — Shortcut building blocks (available, no AppShortcut)
   ┌─────────────────────────────────────────────────────────┐
   │  CheckRequestStatusIntent — "are my requests ready"     │
   │  DownloadForOfflineIntent  — pre-flight automations     │
   │  MarkAsWatchedIntent       — power-user toggles         │
   └─────────────────────────────────────────────────────────┘

   Tier 3 — System integrations (the right way, not a custom intent)
   ┌─────────────────────────────────────────────────────────┐
   │  @AssistantIntent(schema: .media.search)   — AI index   │
   │  INPlayMediaIntent donation after playback              │
   │  SetFocusFilterIntent — server scope per Focus mode     │
   └─────────────────────────────────────────────────────────┘
```

## What Changes

- **AppEntity foundation** — `MediaItemEntity` and `RequestEntity` defined
  in `SeerCore`, backed by `OfflineSync`'s SwiftData cache so entity queries
  are instant and offline-tolerant. `ServerEntity` represents a configured
  Jellyfin/Jellyseerr pair for multi-server disambiguation.
- **AppShortcutsProvider** registers the Tier 1 trio. The provider lives
  in the app target (`App/SeerApp/AppIntents/`) because `AppShortcutsProvider`
  must be discovered at the app level.
- **Tier 1 intents** — `RequestMediaIntent`, `SearchMediaIntent`,
  `ResumeWatchingIntent`. All three accept an optional `ServerEntity` param
  defaulting to `AppState.activeServer` (multi-server hybrid).
- **Tier 2 intents** — `CheckRequestStatusIntent`, `DownloadForOfflineIntent`,
  `MarkAsWatchedIntent`. Available in Shortcuts but not auto-surfaced.
- **Tier 3 system integration** — Conform `SearchMediaIntent` to
  `AssistantSchemas.media.search` (iOS 18+; trivially available on the
  iOS 26 floor). Donate `INPlayMediaIntent` after every successful playback
  start so "play X again" routes to Seer specifically. Provide a
  `SeerFocusFilter` (`SetFocusFilterIntent`) that pins the active
  `ServerEntity` for the duration of a Focus mode.
- **Spotlight semantic indexing** of `MediaItemEntity` is gated behind a
  new `appIntentsIndexingEnabled` setting under
  `Features/Feedback/PrivacySettingsView`, defaulting **off**, in keeping
  with Seer's existing opt-in stance for any data surfacing outside the
  app's process.
- **iOS only for v1.** tvOS App Intents are a much thinner surface (no
  Action Button, no Focus Filters in the same form, no interactive
  widgets). Voice and Shortcuts on tvOS will work via iCloud sync from
  iPhone for free; deferring tvOS-specific work keeps the v1 scope honest.

## Capabilities

### New Capabilities

- `app-intents-foundation`: AppEntity types (`MediaItemEntity`,
  `RequestEntity`, `ServerEntity`), entity queries reading from
  `OfflineSync`, multi-server resolution rules, AppShortcutsProvider, and
  the Spotlight indexing consent gate.
- `app-intents-actions`: the six verb intents (Tier 1 + Tier 2) and their
  parameter resolution / not-signed-in behavior. Owns the rules that
  govern what the intents do, what they return, and how they fail.
- `app-intents-system-integration`: AssistantSchema conformance,
  `INPlayMediaIntent` donation policy, and the Focus Filter that pins
  active server scope.

### Modified Capabilities

(None. There are no existing specs in `openspec/specs/` covering App
Intents, system search, or Focus Filters — this proposal introduces
the first.)

## Impact

**Affected code (new and modified):**

- `App/SeerApp/AppIntents/` (NEW) — `SeerAppShortcutsProvider`,
  `SeerFocusFilter`, intent dialog snippet views.
- `Packages/SeerCore/Sources/SeerCore/AppIntents/` (NEW) —
  `MediaItemEntity`, `RequestEntity`, `ServerEntity`,
  `MediaItemEntityQuery`, `RequestEntityQuery`, `ServerEntityQuery`.
  These live in `SeerCore` because every `Features/` target depends on
  it and entity types must be visible to both the app and any future
  extension. SwiftData reads route through the existing `OfflineSync`
  surface.
- `Packages/SeerCore/Sources/SeerCore/AppIntents/Intents/` (NEW) —
  the six `AppIntent` types. Each constructs the same services that
  ViewModels construct today (`JellyfinService`, `JellyseerrService`)
  using `AppState` credentials.
- `Packages/JellyfinClient/`, `Packages/JellyseerrClient/` — no API
  surface changes. The intents call the existing methods that today's
  ViewModels call. Dependency direction stays features → clients →
  SeerCore; intents follow the same direction.
- `Packages/PlaybackClient/Sources/PlaybackClient/` — add
  `INPlayMediaIntent` donation hook in the playback start path.
- `Features/Feedback/PrivacySettingsView.swift` — add
  `appIntentsIndexingEnabled` toggle (off by default), wired to
  `AppState`.
- `App/SeerApp/SeerApp.swift` — opt the app into App Intents at app
  launch (the framework's automatic registration handles the rest);
  add `onOpenURL` handling for the `flowmark://` scheme dispatched to
  `ContentView`.
- `App/SeerApp/Info.plist` (or the equivalent `project.yml`
  `infoPlist` entries) — register `CFBundleURLSchemes = ["flowmark"]`.
  Brand-aligned with the App Store listing name "Flowmark Media"; not
  the engineering bundle name "Seer".
- `project.yml` — no new SwiftPM dependencies. App Intents and
  Intents.framework ship with the SDK. Adds `CFBundleURLTypes` entry.

**Platforms:** iOS only for v1. tvOS scoped out (separate change).

**Privacy:** Spotlight indexing of `MediaItemEntity` is opt-in and gated
behind a privacy setting that defaults off. Indexed payload contains
title, year, type, and entity identifier — no posters, no descriptions,
no per-item watched state. Index is rebuilt from `OfflineSync` and never
reaches the network on the indexing path. No telemetry events are added
under this change.

**Telemetry:** None added. App Intents invocations are not logged
(privacy posture: voice and system-dispatched actions are inherently
intimate).

**Migration:** None. All new additions; nothing existing is removed or
renamed. Users with no `OfflineSync` cache yet (fresh install) see no
intent results until the cache populates after first sign-in — the
intents return a "no matches yet — open Seer to populate your library"
result snippet.
