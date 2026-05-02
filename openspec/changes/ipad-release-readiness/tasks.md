<!-- TDD-EXEMPT: release tooling + metadata changes; no in-app behavior to test red-first. The XCUITest update IS test code, so it follows a self-test pattern (test passes when it captures the right screens). -->

## 1. Setup

- [ ] 1.1 Verify `iPad Pro 13-inch (M5)` simulator is installed and
  bootable (`xcrun simctl list devices | grep "iPad Pro 13-inch"`).
  If renamed in current Xcode, update `fastlane/Snapfile`.
- [ ] 1.2 Confirm App Store Connect API key still valid; run `fastlane
  show_build_number` as a smoke test.
- [ ] 1.3 Take an inventory of current ASC iPad listing state
  (compatible devices, screenshots present/absent) so the post-
  release diff is verifiable.

## 2. Test-side updates (replaces "Tests (red)")

- [ ] 2.1 Add `private func tapTab(_ label: String, in app:
  XCUIApplication)` helper to `Tests/SeerAppUITests/SnapshotTests.swift`
  that branches on `UIDevice.current.userInterfaceIdiom`: phone uses
  `app.tabBars.buttons[label]`, pad uses
  `app.collectionViews.buttons[label]` (or whichever XCUIElement the
  sidebar TabView produces — verify in 4.1).
- [ ] 2.2 Replace existing `app.tabBars.buttons["Search"]` and
  `app.tabBars.buttons["Downloads"]` calls with `tapTab(...)`.
- [ ] 2.3 Extend `testCaptureScreenshots` to capture an expanded set
  on iPad: Library + Library-with-detail (tap a tile to populate
  detail column) + Discover + Search + Requests + Downloads + Servers
  (open sidebar Servers destination). iPhone keeps the current 3
  shots.
- [ ] 2.4 Snapshot file naming: `0N-<Surface>.png` with two-digit
  ordering for ASC slot stability.
- [ ] 2.5 Run `make fastlane-screenshots` locally; verify
  `fastlane/screenshots/en-US/iPad Pro 13-inch (M5)/` contains all 7
  iPad shots and `iPhone 17 Pro Max/` retains its 5 shots
  (renaming to add Discover + Requests).

## 3. Fastlane / deliver integration

- [ ] 3.1 In `fastlane/Fastfile`, extend `lane :screenshots` to
  optionally upload after capture:
  `deliver(skip_binary_upload: true, force: true,
   overwrite_screenshots: true, run_precheck_before_submit: false)`
  behind a `:upload` lane option (default false).
- [ ] 3.2 In `lane :release`, chain `deliver(force: true,
  overwrite_screenshots: true,
  submit_for_review: false)` after `upload_to_app_store`-equivalent
  step so the next release pushes screenshots automatically.
- [ ] 3.3 Verify `fastlane/Deliverfile` is correctly empty or has
  required keys (currently empty per `cat fastlane/Deliverfile`); add
  `app_identifier` and `username` if needed (Appfile may already
  cover).

## 4. App Store Connect verification (manual)

- [ ] 4.1 Run `make fastlane-screenshots` and visually inspect every
  iPad shot — content readable, no permission dialogs, no save-
  password sheet leak, sidebar fully visible.
- [ ] 4.2 Run `fastlane screenshots upload:true` (using the option
  added in 3.1) — verify ASC shows iPad screenshots in preview.
- [ ] 4.3 In App Store Connect, verify the listing shows "Compatible
  with iPad" / iPad badge after upload.
- [ ] 4.4 Verify "Designed for iPad" Mac App Store availability toggle
  is ON.
- [ ] 4.5 Update `fastlane/metadata/en-US/release_notes.txt` with an
  entry advertising iPad support (one paragraph; mention sidebar,
  split view, hardware keyboard, multi-window playback if Proposal 3
  shipped).
- [ ] 4.6 Review `description.txt`, `subtitle.txt`, `keywords.txt` for
  iPad mentions; update if they read as iPhone-only.
- [ ] 4.7 Submit a TestFlight build via `fastlane beta`; install on
  iPad Pro 13" + iPhone 17 + Mac (Designed-for-iPad); confirm no
  regressions.

## 5. Documentation

- [ ] 5.1 Update `docs/releases.md` with an "iPad release runbook"
  section: capture workflow, `deliver` flow, ASC iPad listing
  verification, Mac availability toggle.
- [ ] 5.2 Update `docs/onboarding.md` (if it references screenshot
  testing) with the idiom-branch helper note.
- [ ] 5.3 Run `make lint` and `make format`.

## 6. Refactor (optional)

- [ ] 6.1 Extract a `ScreenshotNavigation` helper struct from
  `SnapshotTests` if the test grows further; keeps idiom logic in
  one place.
- [ ] 6.2 Consider auto-generating `release_notes.txt` from
  release-please's CHANGELOG entry — defer; orthogonal to iPad work.
