## ADDED Requirements

### Requirement: Idiom-aware UI snapshot test

The `Tests/SeerAppUITests/SnapshotTests.swift` UI test SHALL
successfully drive the app on both iPhone and iPad simulators by
branching its navigation queries on
`UIDevice.current.userInterfaceIdiom`. The test MUST capture
screenshots for the surfaces appropriate to each idiom without
manual intervention.

#### Scenario: iPhone capture path uses the bottom tab bar

- **WHEN** the snapshot test runs on iPhone 17 Pro Max compact portrait
  via `make fastlane-screenshots`
- **THEN** the test MUST locate tab buttons via
  `app.tabBars.buttons[label]`, MUST capture at least Library, Search,
  and Downloads, MUST place the resulting PNGs in
  `fastlane/screenshots/en-US/iPhone 17 Pro Max/`, and MUST exit with
  status 0

#### Scenario: iPad capture path uses the sidebar

- **WHEN** the snapshot test runs on iPad Pro 13-inch (M5) regular
  landscape via `make fastlane-screenshots` (after Proposal
  `ipad-navigation-shell` has shipped)
- **THEN** the test MUST locate sidebar entries via the appropriate
  XCUIElement query (per Decision 2 in `design.md`), MUST capture
  Library, Library with detail, Discover, Search, Requests,
  Downloads, and Servers (7 surfaces), MUST place the resulting PNGs
  in `fastlane/screenshots/en-US/iPad Pro 13-inch (M5)/`, and MUST
  exit with status 0

### Requirement: Fastlane lane uploads iPad screenshots

The `lane :screenshots` SHALL accept an `:upload` option that, when
true, invokes `deliver` to push the captured screenshots to App Store
Connect with `skip_binary_upload: true` and `overwrite_screenshots:
true`. The release lane SHALL chain `deliver` after the binary upload
so iPad screenshots ship with each release.

#### Scenario: Manual screenshot upload via fastlane

- **WHEN** a maintainer runs `fastlane screenshots upload:true` from
  the project root
- **THEN** captured screenshots from
  `fastlane/screenshots/en-US/iPhone 17 Pro Max/` and
  `fastlane/screenshots/en-US/iPad Pro 13-inch (M5)/` MUST be uploaded
  to App Store Connect, the binary MUST NOT be re-uploaded, and any
  prior iPad screenshots in ASC MUST be overwritten

#### Scenario: Release lane uploads screenshots with binary

- **WHEN** a maintainer runs `fastlane release` for a TestFlight-
  promotion release
- **THEN** the binary upload step MUST run first, the screenshot
  upload step MUST run after, and any failure in the screenshot step
  MUST surface in the release log without aborting the release

### Requirement: App Store Connect listing reflects iPad compatibility

The App Store Connect listing SHALL show iPad as a supported device
class with at least one iPad screenshot in the gallery after this
proposal's first release lands, and the Mac (Designed-for-iPad)
availability toggle MUST be on.

#### Scenario: First release after Proposal lands shows iPad listing

- **WHEN** a release after Proposal `ipad-release-readiness` has been
  archived and pushed to App Store Connect via `fastlane release`
- **THEN** the App Store listing MUST show "Compatible with iPad"
  (badge or analogous indicator current on ASC), MUST include at
  least one iPad screenshot, and the Mac App Store availability
  setting MUST report the app as available on Mac

#### Scenario: Mac (Designed-for-iPad) inherits iPad screenshots

- **WHEN** the App Store Connect "Mac App Store" availability toggle
  is on for the app and an iPad screenshot set has been uploaded
- **THEN** the Mac listing MUST show the same iPad screenshots
  without requiring a separate upload

### Requirement: Documentation captures the iPad release flow

The repository SHALL document the iPad release flow in
`docs/releases.md` such that a contributor can:
1. Capture iPad screenshots locally,
2. Upload them via fastlane,
3. Verify the App Store Connect listing,
4. Toggle Mac availability,

without prior context beyond the existing release docs.

#### Scenario: Contributor follows the iPad release runbook

- **WHEN** a contributor with no prior knowledge of the iPad release
  flow follows `docs/releases.md`'s "iPad release runbook" section
- **THEN** they MUST be able to produce a complete iPad screenshot
  set, upload it, and verify the App Store listing without consulting
  any other source — measured by a successful dry-run during 4.x
  verification
