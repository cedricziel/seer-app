## Context

Today's release pipeline:

- `make fastlane-beta` builds + uploads to TestFlight (every commit on
  `main` per repo convention).
- `make fastlane-release` promotes a TestFlight build to the App Store.
- `lane :screenshots` invokes `capture_ios_screenshots` against the
  Snapfile's listed devices.
- `Snapfile` lists `iPhone 17 Pro Max` and `iPad Pro 13-inch (M5)`.
- `SnapshotTests.swift` only knows about the iPhone tab-bar path.
- `fastlane/screenshots/en-US/` contains the iPhone shots; iPad
  output is empty or incorrect.
- App Store Connect metadata in `fastlane/metadata/en-US/` is iPhone-
  centric.
- `TARGETED_DEVICE_FAMILY: "1,2"` is set, so TestFlight installs
  already work on iPad. The App Store listing shows iPad as compatible
  *as soon as iPad screenshots are uploaded*.

This proposal closes the gap: idiom-aware snapshot tests, expanded
iPad capture, and the `deliver` glue to push iPad shots to App Store
Connect.

## Goals / Non-Goals

**Goals:**
- `make fastlane-screenshots` produces a complete iPad capture set in
  one run, alongside the existing iPhone set.
- `fastlane release` uploads iPad screenshots so the next App Store
  release shows the iPad listing.
- Contributors can re-run screenshot capture without manual
  intervention or post-processing.
- Mac App Store (Designed-for-iPad) inherits iPad shots automatically.

**Non-Goals:**
- App preview videos (separate concern; nice-to-have).
- Localized iPad screenshots beyond `en-US` (locale strategy is
  separate; current project ships en-US only).
- CI-driven screenshot capture (manual capture stays the norm; CI
  changes are out of scope).
- Marketing redesign (existing screenshots are the baseline; this
  proposal captures the new shell on iPad as-is).
- New ASC privacy / data-collection disclosures (none introduced).

## Decisions

**1. Idiom branch in the test, not separate test classes.** A single
`SnapshotTests.testCaptureScreenshots` driven by
`UIDevice.current.userInterfaceIdiom` keeps the test surface small
and shares onboarding setup. Branching is local to navigation
queries, not a fork of the test class.

**2. Helper `tapTab(_:in:)` resolves bottom-tab vs sidebar.** Wraps
the idiom check. iPhone uses `app.tabBars.buttons[label]`; iPad uses
`app.outlines.buttons[label]` or `app.collectionViews.buttons[label]`
depending on what `.tabViewStyle(.sidebarAdaptable)` produces.
Resolved during 1.x verification.

**3. Capture more shots on iPad than iPhone.** The iPhone set is
optimized for the 6.9" listing's first-impression slots. iPad has
more screen area and the listing supports more screenshots; capture
Library + Library-with-detail + Discover + Search + Requests +
Downloads + Servers (7 shots) versus the iPhone 5.

**4. `deliver` runs from the screenshots lane and the release lane.**
`deliver(skip_binary_upload: true, force: true,
overwrite_screenshots: true)` for metadata-only refreshes; the
release lane chains `build_app → deliver` so the binary and screenshots
upload together.

**5. No CI capture for now.** UI tests against a public Jellyfin demo
flake under CI load. Manual capture from a known-good local Jellyfin
(see `docker/jellyfin/`) is the practical bar. Document the steps.

**6. `release_notes.txt` is empty by default; populated per release.**
ASC treats empty release notes as "use previous". Set explicitly when
a release should advertise iPad support.

## HIG & Layout

N/A — non-UI change (release tooling and App Store metadata).

The screenshots themselves are governed by Proposal 1's HIG section
since they capture the iPad shell. This proposal only ensures they
get captured and uploaded.

## Risks / Trade-offs

- **[Risk] Sidebar query selectors are unstable across SwiftUI iOS
  versions.** → Mitigation: test the helper against iPad simulator
  during 1.x; fall back to `app.descendants(matching: .button)
  .matching(identifier:)` if the outline path changes.
- **[Risk] `iPad Pro 13-inch (M5)` simulator name drifts as Apple
  renames device classes.** → Mitigation: extract device names to a
  single `Snapfile` and verify before each release. `make fastlane-
  screenshots` should fail loudly if the named device isn't installed.
- **[Risk] App Store Connect changes required iPad screenshot sizes.**
  → Mitigation: verify against ASC at the start of each release cycle;
  current `iPad Pro 13" (M5)` is the canonical iPad screenshot device
  for 2026.
- **[Risk] Public Jellyfin demo server is down at capture time.** →
  Mitigation: existing test docs say re-run when demo is healthy; same
  guidance applies.
- **[Trade-off] `deliver` `overwrite_screenshots: true` clobbers
  manually-curated ASC uploads.** → Accept; this proposal makes the
  fastlane flow authoritative. Manual ASC edits are not a supported
  workflow going forward.

## Migration Plan

No data migration. Rollout:

1. Land this proposal's diff (test helper + Fastfile changes + docs)
   alongside Proposal 1.
2. Run `make fastlane-screenshots` locally — verify both iPhone and
   iPad output complete. Inspect outputs visually.
3. First release after Proposal 1 ships: invoke `fastlane release`,
   which uploads the binary and the iPad screenshots in one pass. ASC
   automatically begins showing iPad as a supported device on listing
   refresh.
4. Verify the listing in ASC; toggle Mac availability ON if it isn't
   already.

Rollback: if `deliver` corrupts ASC metadata, ASC retains prior
metadata for the active App Store version. Manual revert via ASC
console is possible. The repo-side Fastfile change is a normal git
revert.

## Open Questions

- Does the App Store currently *require* additional iPad sizes (11",
  10.9") beyond 13"? Verify against ASC at land time. Lean: 13" alone
  is sufficient as of 2026 for "Compatible with iPad".
- Should `release_notes.txt` be templated per release-please version
  bump? Probably yes — but out of scope; would extend release-please
  config.
- Does `deliver` need a separate Apple ID per environment, or does
  the App Store Connect API key cover it? `Fastfile` already uses
  `load_app_store_connect_api_key` for `build_app` /
  `upload_to_testflight` — `deliver` should pick up the same key. Verify.
- Is "Designed for iPad" enabled on the Mac App Store side? Should
  document the toggle position in App Store Connect for future
  contributors.
