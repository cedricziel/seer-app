## Why

Once Proposals 1–3 land, Seer will be a real iPad app. But "real iPad
app" means more than the bits running well — it means the App Store
listing shows iPad as a supported device, with iPad screenshots in App
Store Connect and an iPad-aware fastlane pipeline. Today the
infrastructure is half-wired: `Snapfile` lists `iPad Pro 13-inch (M5)`
as a target device, but `Tests/SeerAppUITests/SnapshotTests.swift`
drives the app via `app.tabBars.buttons["Search"]` — which won't find
anything on iPad regular width once the sidebar shell ships. The
`fastlane/screenshots/en-US/` directory has only iPhone output. App
Store Connect metadata makes no iPad-specific claims. TestFlight and
Mac (Designed-for-iPad) already include iPad for free since
`TARGETED_DEVICE_FAMILY: "1,2"` and
`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: true` are already set, but
the *store presentation* needs the screenshots and metadata.

## What Changes

- **`SnapshotTests.swift` becomes idiom-aware**: branches on
  `UIDevice.current.userInterfaceIdiom` to navigate via either the
  bottom tab bar (iPhone) or the sidebar tabs (iPad regular width).
  Replace `app.tabBars.buttons["Search"]` lookups with a helper that
  picks the right navigation surface.
- **Expanded iPad capture set**: iPad runs add Library (with detail
  selected), Discover, Search (with results), Requests, Downloads,
  MediaDetail, and Servers (sidebar destination). iPhone keeps the
  existing 3-shot capture as the regression baseline.
- **Verify Snapfile devices** match currently shipping App Store
  Connect device classes. iPad Pro 13" (M5) is the primary required
  iPad screenshot size; verify whether ASC also requires/accepts 11"
  iPad. Update `Snapfile` if Apple's required set has changed.
- **Wire screenshots into the release lane**: `fastlane beta` and
  `fastlane release` invoke `deliver` with `submit_for_review: false`
  for the metadata upload step. Verify deliver picks up iPad
  screenshots from `fastlane/screenshots/en-US/iPad Pro 13-inch (M5)/`.
- **App Store metadata refresh**: review
  `fastlane/metadata/en-US/description.txt`,
  `subtitle.txt`, `keywords.txt`, `promotional_text.txt` — confirm
  copy mentions iPad use cases (split view, Stage Manager, hardware
  keyboard) where appropriate. Add a `release_notes.txt` entry for the
  iPad release.
- **Marketing version cadence**: the iPad shell is a meaningful
  release. Coordinate with release-please so the version bump for
  the iPad reshape is at least a minor-version bump
  (`x-release-please-version` markers in `project.yml`). Document in
  `docs/releases.md`.
- **Mac App Store availability check**: `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD`
  is already true, but verify in App Store Connect that the "Mac App
  Store" availability toggle is set so the Mac variant ships
  alongside the iPad release. Document the setting in
  `docs/releases.md`.

## Screen-by-Screen Reshape

This proposal does not change in-app screens. It changes the screenshot
pipeline and the App Store listing surface.

### Screenshot pipeline — before

```
  make fastlane-screenshots
       │
       ▼
   fastlane snapshot (Snapfile lists 2 devices)
       │
       ├──► iPhone 17 Pro Max ──► SeerAppUITests/SnapshotTests
       │                            uses app.tabBars.buttons[…]   ✓
       │                            │
       │                            ▼
       │                       fastlane/screenshots/en-US/iPhone…/
       │                          ├── 01-Library.png
       │                          ├── 02-Search.png
       │                          └── 03-Downloads.png
       │
       └──► iPad Pro 13-inch (M5) ──► same SnapshotTests
                                        app.tabBars.buttons[…]
                                                ✗ no tabBars on sidebar
                                                  test fails or captures
                                                  wrong screen
                                        fastlane/screenshots/en-US/
                                        iPad Pro 13…/  empty / partial
```

### Screenshot pipeline — after

```
  make fastlane-screenshots
       │
       ▼
   fastlane snapshot
       │
       ├──► iPhone 17 Pro Max ──► SnapshotTests (tabBars path)
       │                            ├── 01-Library.png
       │                            ├── 02-Discover.png
       │                            ├── 03-Search.png
       │                            ├── 04-Requests.png
       │                            └── 05-Downloads.png
       │
       └──► iPad Pro 13-inch (M5) ──► SnapshotTests (sidebar path)
                                       │  branches on UIDevice.idiom
                                       ▼
                                  ├── 01-Library.png       (3-col split)
                                  ├── 02-Library-Detail.png (detail col)
                                  ├── 03-Discover.png
                                  ├── 04-Search.png
                                  ├── 05-Requests.png
                                  ├── 06-Downloads.png
                                  └── 07-Servers.png

   fastlane beta / fastlane release
       │
       ├── build_app + upload_to_testflight
       └── deliver (metadata + screenshots → App Store Connect)
                │
                ▼
       App Store listing shows:
       • "Compatible with iPad" badge ✓
       • iPad screenshots gallery ✓
       • Mac (Designed for iPad) availability ✓
```

### App Store Connect listing flow

```
  Build ipa (TARGETED_DEVICE_FAMILY=1,2)
        │
        ▼
   App Store Connect receives build
        │
        ├──► iPhone listing  (existing)
        │      └── 6.9" + 6.5" iPhone screenshots
        │
        ├──► iPad listing    (NEW after this proposal)
        │      └── iPad Pro 13" screenshots required
        │
        └──► Mac App Store listing (Designed-for-iPad)
               └── inherits iPad screenshots automatically;
                   Mac availability toggle must be ON
```

## Capabilities

### New Capabilities
- `ipad-release-readiness`: idiom-aware UI snapshot test, expanded
  iPad capture set, fastlane / `deliver` integration for App Store
  Connect iPad metadata, and the documentation around release
  cadence and Mac availability.

### Modified Capabilities
(None.)

## Impact

**Affected code:**
- `Tests/SeerAppUITests/SnapshotTests.swift` — branches on
  `UIDevice.current.userInterfaceIdiom`; new helper
  `tapTab(_:in:)` chooses tab-bar or sidebar source.
- `fastlane/Snapfile` — verify device list; add per-device language
  partitioning if Apple's required size set changes.
- `fastlane/Fastfile` — `lane :screenshots` augmented to invoke
  `deliver(skip_binary_upload: true, force: true)` for the metadata-
  only upload after capture; existing `lane :beta` and `lane :release`
  call out to it where appropriate.
- `fastlane/metadata/en-US/release_notes.txt` — entry for the iPad
  release.
- `fastlane/metadata/en-US/description.txt`,
  `subtitle.txt`, `keywords.txt`,
  `promotional_text.txt` — copy review for iPad mentions.
- `docs/releases.md` — iPad release runbook section: screenshot
  capture, deliver flow, Mac availability toggle, version-bump
  guidance.
- `docs/onboarding.md` — note the screenshot test idiom branch so
  future contributors know.

**Platforms:** iPad (primary), iPhone (regression: existing capture
must still produce 3 shots), Mac via Designed-for-iPad (free,
verification only).

**Dependencies:** None new. `fastlane snapshot` and `deliver` are
already in the project. App Store Connect API key is already wired
(see `fastlane/Appfile` and `load_app_store_connect_api_key` in
`Fastfile`).

**Telemetry:** None (release tooling, not in-app).

**Migration:** No data migration. App Store Connect: first release
after this proposal lands MUST upload iPad screenshots; subsequent
releases use the same flow.

**Sequencing:** Depends on Proposal 1 (`ipad-navigation-shell`)
having shipped. The sidebar path in `SnapshotTests.swift` is
meaningless without the sidebar shell. Proposals 2 and 3 are
beneficial (better screenshots once shortcuts and detached player
exist) but not blocking.
