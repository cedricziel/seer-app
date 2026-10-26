# Releases

Two channels, both modelled through release-please's GitHub Releases:

- **TestFlight** — every release-please-created release is marked as a
  pre-release in GitHub. Merging the release PR uploads to TestFlight.
- **App Store** — explicit graduation. Click "Set as the latest release" on
  the GitHub release page → that fires `release: released` → the existing
  TestFlight build is submitted for App Store review (no rebuild).

Same tag, same artifact for both channels. The GitHub Release's
prerelease/released flag is the channel state.

## Channel mechanics

```
semantic commits land on main
   │
   └─► release-please opens / updates "chore(main): release X.Y.Z" PR
          │
          └─► merge ─► tag vX.Y.Z + GitHub Release (prerelease=true)
                 │
                 └─► testflight job ─► fastlane beta ─► uploads to TestFlight

[ test in TestFlight, decide this build is App-Store-ready,
  go to the release page and "Set as the latest release" ]
   │
   └─► GitHub fires release: released
          │
          └─► app-store workflow ─► fastlane submit_to_app_store ─► review queue
```

## Two version components

The App Store binary carries two numbers:

| Component | Field | Source |
|---|---|---|
| Marketing version | `CFBundleShortVersionString` | release-please writes `MARKETING_VERSION` into `project.yml`. |
| Build number      | `CFBundleVersion`            | `git rev-list --count HEAD` injected at archive time via `xcargs`. |

Build number is derived from git history — never written back to
`project.yml`. Same git state, same build number.

## TestFlight (pre-release path)

Triggered automatically when release-please's PR is merged to `main`. The
`testflight` matrix in `release-please.yml` builds iOS, tvOS, and native macOS
independently. A failure on one platform does not cancel the others. Each job:

1. Checks out the tag release-please just created.
2. Resolves signing via `match` against `cedricziel/certificates`.
3. Builds with `CURRENT_PROJECT_VERSION = git rev-list --count HEAD`.
4. Uploads to TestFlight using the App Store Connect API key.
5. Uploads dSYMs.
6. Posts its IPA or macOS PKG and dSYM archive as workflow artifacts for 30 days.

All platforms use the same bundle ID, marketing version, and commit-count build
number. macOS uses the macOS SDK with SwiftUI and AppKit, with Mac Catalyst and
Designed for iPad on Mac disabled. The Mac archive includes Apple silicon and
Intel architectures under the standard Release build settings.

### Prepare signing for new platforms

Add tvOS and macOS to the existing app record in App Store Connect before the
first upload. Enable the required iCloud capabilities for the app identifier on
each platform. Use the existing App Store Connect credentials and match repository.

Run these commands locally with signing-write access before the first release:

```sh
bundle exec fastlane bootstrap_signing target:tvos
bundle exec fastlane bootstrap_signing target:macos
```

The macOS command also provisions a Mac Installer Distribution certificate for
PKG signing. CI fetches profiles and certificates with `readonly: true`. Expected
profile names are `match AppStore com.cedricziel.seer tvos`,
`match Development com.cedricziel.seer macos`, and
`match AppStore com.cedricziel.seer macos`. tvOS fetches the development certificate
without a development profile, so releasing does not require a registered Apple TV.
The Wi-Fi information entitlement applies only to iOS. macOS enables App Sandbox
and outbound network access.

To upload a single platform manually:

```sh
bundle exec fastlane beta target:ios
bundle exec fastlane beta target:tvos
bundle exec fastlane beta target:macos
```

Omitting `target` retains the existing iOS behavior. Platform artifacts are written
to `build/ios`, `build/tvos`, or `build/macos`. The App Store graduation matrix submits all three existing TestFlight builds
without rebuilding. Each job uses the release tag version and commit-count build
number. Prepare platform screenshots and required review metadata in App Store
Connect before graduating a release.

## App Store (graduation path)

Every release-please release lands as a GitHub **pre-release**
(`prerelease: true` in `release-please-config.json`). Promotion to App
Store is one click in the GitHub UI:

1. Open the release on GitHub (e.g. `vX.Y.Z`).
2. Click **Edit**, uncheck "Set as a pre-release", check "Set as the latest
   release", click **Update release**.
3. GitHub fires `release: released`. the `app-store` matrix in `release-please.yml` runs and calls
   `fastlane submit_to_app_store target:<platform>` with the version from the
   release tag and build number computed from the
   tagged commit. `skip_binary_upload: true` means the **existing**
   TestFlight build is added to the App Store version and submitted for
   review — no rebuild, no re-upload.
4. Apple reviews. On approval, Apple awaits your manual release
   (`automatic_release: false`).

The binary submitted to Apple is byte-identical to what TestFlight testers
used.

## Off-cycle / manual paths

| Need | Command |
|---|---|
| Ad-hoc TestFlight build from local | `make fastlane-beta` |
| Force-rebuild App Store submission (skips graduation) | `make fastlane-release submit:true` |
| Inspect what would be built | `make version` |

## File map

| File | Purpose |
|------|---------|
| `release-please-config.json` | Per-package release-please config. `prerelease: true` keeps every release marked as pre-release until graduated. |
| `.release-please-manifest.json` | Source of truth for the current released version. |
| `.github/workflows/release-please.yml` | One workflow, three jobs: `release-please` (push to main → release PR / tag), `testflight` (depends on release-please outputs → builds & uploads to TestFlight), `app-store` (triggered by `release: released` → submits existing TestFlight build for review). |
| `CHANGELOG.md` | Auto-generated by release-please. |

## Authenticating release-please

The `release-please` job reads `RELEASE_PLEASE_TOKEN` from Actions secrets if
present, falling back to `GITHUB_TOKEN`. Configure a dedicated token when you
want the release/tag created by release-please to trigger downstream
workflows — `GITHUB_TOKEN`-authored events are intentionally suppressed by
GitHub from cascading to other workflow runs.

A fresh fine-grained personal access token works:

- **Repository access:** only this repo (`cedricziel/seer-app`).
- **Permissions:**
  - Contents — Read and write (commit, tag, create release)
  - Pull requests — Read and write (open release PRs)
  - Metadata — Read (always required)
- **Expiration:** whatever your team policy is; rotate via `gh secret set`.

Then:

```bash
gh secret set RELEASE_PLEASE_TOKEN --repo cedricziel/seer-app < /path/to/token
```

If no `RELEASE_PLEASE_TOKEN` is set, release-please still works using
`GITHUB_TOKEN`; only cross-workflow triggering on the release event is
suppressed.

## Conventional commit cheat sheet

| Type | Effect on version |
|------|--------|
| `feat:` | minor |
| `fix:` | patch |
| `feat!:` / `fix!:` / footer `BREAKING CHANGE:` | major (or minor pre-1.0) |
| `perf:` | patch |
| `revert:` | patch |
| `chore:`, `ci:`, `docs:`, `style:`, `test:`, `refactor:`, `build:` | no version bump → no release PR → no TestFlight build |

While we're pre-1.0, `feat!` produces a minor bump rather than a major
(`bump-minor-pre-major: true`). Flip that knob in
`release-please-config.json` once you cut 1.0.
