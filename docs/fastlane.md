# Fastlane

Seer uses [fastlane](https://fastlane.tools) to drive testing, signing, and
TestFlight / App Store releases. The setup is designed to be safe in a public
repository — no secrets, signing material, or App Store Connect credentials
are checked in.

> **Releases:** version bumps and tags are managed by [release-please](releases.md).
> Fastlane's job is just to build and upload — it picks up whatever
> `MARKETING_VERSION` release-please has already written into `project.yml`.

## TL;DR

```bash
make setup                 # installs xcodegen + swiftlint + swiftformat + ruby (Homebrew)
make fastlane-install      # bundle install fastlane via Homebrew Ruby
cp fastlane/.env.example fastlane/.env
$EDITOR fastlane/.env      # fill in real values (this file is gitignored)
make fastlane-test         # run the test suite
make fastlane-beta         # ship a TestFlight build
```

> All `fastlane-*` Make targets invoke `$(brew --prefix ruby)/bin/bundle`
> directly. macOS system Ruby (2.6) is intentionally avoided — it frequently
> fails to install fastlane's native gems. Targets fail fast if Homebrew Ruby
> isn't on the machine.

## Available lanes

| Lane | What it does |
|------|--------------|
| `test` | Runs unit test bundles on the iOS simulator. |
| `build` | Builds and exports a Release IPA into `build/` (no upload). |
| `beta` | Archive + upload to TestFlight. |
| `release` | Archive + upload to App Store Connect. Pass `submit:true` to also submit for review. Uploads metadata by default; pass `metadata:false` to skip. |
| `submit_to_app_store` | Submits an existing TestFlight build to review without rebuilding. Uploads metadata by default; pass `metadata:false` to skip. |
| `sync_metadata` | Pushes `fastlane/metadata/` to App Store Connect without touching the binary or screenshots. Useful for copy-only edits. |
| `sync_signing` | Pulls signing certs/profiles via `match`. Pass `type:development\|appstore`. |
| `bootstrap_signing` | One-time: creates new certs/profiles in your match repo. |
| `refresh_dsyms` | Downloads dSYMs from App Store Connect and uploads them to your crash backend. |
| `bump_build` / `bump_version` | Wraps the existing `scripts/bump-*.sh` helpers. |

Run any lane via the Makefile (`make fastlane-<lane>`) or directly with
`bundle exec fastlane <lane>`.

## Required configuration

Every variable below is read from the environment. Locally, put them in
`fastlane/.env` (gitignored). In CI, configure them as Actions secrets — see
`.github/workflows/beta.yml`. `fastlane/.env.example` is the canonical list.

### App Store Connect API key

Generate at <https://appstoreconnect.apple.com/access/integrations/api>:

1. Create a key with **Admin** or **App Manager** role.
2. Download the `AuthKey_XXXXXXXXXX.p8` file (Apple only lets you download once).
3. Note the **Key ID** and **Issuer ID**.

Then set:

| Variable | Value |
|----------|-------|
| `ASC_KEY_ID` | The 10-character key ID |
| `ASC_ISSUER_ID` | The issuer UUID |
| `ASC_KEY_PATH` *or* `ASC_KEY_CONTENT` | Path to the `.p8` (local) or its contents (CI) |

### match — code signing

Match stores signing identities in a **separate, private** git repository,
encrypted with a passphrase. Do not reuse the public app repo for this.

| Variable | Value |
|----------|-------|
| `MATCH_GIT_URL` | SSH URL of the certificates repo |
| `MATCH_GIT_BRANCH` | Branch to use (defaults to the repo's default branch) |
| `MATCH_PASSWORD` | The match encryption passphrase |
| `MATCH_KEYCHAIN_PASSWORD` | Random string — only needed on CI |

First-time setup on a new bundle ID:

```bash
make fastlane-bootstrap-signing
```

Subsequent runs (locally or in CI) only need read access:

```bash
make fastlane-match TYPE=development
make fastlane-match TYPE=appstore
```

## CI: GitHub Actions

Two workflows are provided:

- **`.github/workflows/ci.yml`** — lint, format check, build, run tests on
  every push and PR. No secrets required.
- **`.github/workflows/release-please.yml`** — manages release PRs and, when
  one is merged, automatically builds and uploads to TestFlight. See
  [`docs/releases.md`](releases.md) for the full flow.

### Required GitHub Actions secrets

| Secret | Used for |
|--------|----------|
| `ASC_KEY_ID` | App Store Connect key ID |
| `ASC_ISSUER_ID` | App Store Connect issuer ID |
| `ASC_KEY_CONTENT` | Contents of the `.p8` file |
| `MATCH_GIT_URL` | SSH URL of the certificates repo |
| `MATCH_PASSWORD` | Match encryption passphrase |
| `MATCH_KEYCHAIN_PASSWORD` | Any random string |
| `MATCH_DEPLOY_KEY` | Read-only SSH deploy key for the certificates repo |

The `production` GitHub Actions environment is used by `beta.yml`, so you can
require reviewers before any TestFlight push.

## Publishing the app repo publicly

Before flipping the repo to public, double-check nothing sensitive is tracked:

```bash
git ls-files | grep -E '\.(p8|p12|mobileprovision|cer)$'   # must be empty
git ls-files | grep -E '(^|/)Secrets\.xcconfig$'           # must be empty (template only)
git ls-files | grep -E '(^|/)\.env$'                       # must be empty
```

The `.gitignore` already excludes all of the above plus any `fastlane/.env*`
files.

## App Store metadata

Fastlane's `deliver` action manages App Store Connect text fields (description,
keywords, subtitle, promotional text, release notes, support/privacy/marketing
URLs, categories, review contact info, age rating, etc.) as plain files under
`fastlane/metadata/<locale>/`. Screenshots and previews live under
`fastlane/screenshots/<locale>/` — those PNGs are gitignored, the metadata text
files are tracked.

### Seeding the tree

If `fastlane/metadata/` doesn't exist yet, pull the current live listing
once. `deliver` only exposes downloads via its CLI subcommand and expects an
ASC API key in JSON form, so do this from a shell with your `.env` loaded:

```bash
# fastlane/metadata/api_key.json (gitignored — DO NOT commit)
cat > fastlane/metadata/api_key.json <<EOF
{ "key_id": "$ASC_KEY_ID",
  "issuer_id": "$ASC_ISSUER_ID",
  "key": $(jq -Rs . < "$ASC_KEY_PATH"),
  "duration": 1200,
  "in_house": false }
EOF

bundle exec fastlane deliver download_metadata \
  --api_key_path fastlane/metadata/api_key.json \
  --app_identifier com.cedricziel.seer \
  --force

rm fastlane/metadata/api_key.json
```

Commit the resulting `fastlane/metadata/<locale>/*.txt` files. From there,
edit text files in git like any other source.

### Pushing copy-only changes

Edited a description or set of keywords without rebuilding the app? Push it:

```bash
make fastlane-sync-metadata
```

This skips the binary and screenshots and just syncs the text fields.

### Release notes from release-please

The `app-store` GitHub Actions job (in `.github/workflows/release-please.yml`)
passes the GitHub release body via the `RELEASE_NOTES` environment variable.
The Fastfile's `stage_release_notes!` helper writes it to
`fastlane/metadata/en-US/release_notes.txt` before `upload_to_app_store` runs,
so each App Store submission inherits the same notes that drove the
release-please version bump.

App Store release notes are plain text and capped at 4000 characters. If your
release-please body uses heavy markdown, either tighten the
`release-notes-section` template in `release-please-config.json` or override
per-release by editing `release_notes.txt` and committing before the release
is graduated.

### What `deliver` doesn't manage

- **App Privacy "Data Types" labels** — managed manually in App Store Connect
  (or via the App Store Connect API directly). See `docs/app-store-privacy.md`.
- **Pricing & availability** — separate App Store Connect API.
- **In-app purchases / subscriptions** — N/A for Seer today; would require a
  separate workflow if added.

## Troubleshooting

- **`xcodegen: command not found`** — run `make setup`.
- **`No suitable application records were found`** — the bundle ID hasn't
  been created in App Store Connect yet.
- **`Could not find a profile matching ...` on CI** — the runner can't reach
  the match repo. Verify `MATCH_DEPLOY_KEY` is set and added as a deploy key
  on the certificates repo.
- **`Code signing is required`** — ensure `sync_signing` ran before
  `build_app`. Both `beta` and `release` already do this.
