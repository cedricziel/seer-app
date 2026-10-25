---
name: verify
description: Verify Seer changes with native builds, isolated hosted unit tests, and OpenAPI regeneration before a PR.
---

# Verify Seer

1. Check `git status --short` and preserve unrelated changes and peer worktrees.
2. Use the SwiftLint and SwiftFormat versions pinned in `.github/workflows/ci.yml`. Run `swiftlint lint --strict --no-cache` and `swiftformat --lint . --cache ignore`. Compare failures with the baseline and format only changed files.
3. Regenerate the project with `xcodegen generate`. Build with `xcodebuild`, temporary derived-data and cloned-package directories, and `CODE_SIGNING_ALLOWED=NO`.
4. Run hosted unit tests on a dedicated disposable simulator with test credentials. Delete the simulator in a cleanup trap. Never use an existing user simulator or device.

Debug hosted unit tests enter `HostedUnitTestApp` through `SeerAppEntryPoint` when XCTest is injected. This bypasses `SeerApp.init`, its CloudKit stores, telemetry, and background services. Ordinary and Release launches retain `SeerApp.main()`. UI tests run XCTest in a separate runner and retain production startup.

The unsigned host was verified with 11 native library-search tests on an isolated simulator. An ad-hoc binary without iCloud entitlements can trap if it enters production CloudKit startup. The SDK `invalidDigitCount` warning also appeared during the successful run; inspect crash reports before diagnosing a launch timeout.

Native builds and visual checks can be blocked by existing source errors or unavailable simulator services. Record exact blockers and leave unavailable checks incomplete.

## OpenAPI changes

Follow the pinned generator setup in [the API package guide](../../../Packages/JellyseerrAPI/README.md). Regenerate twice and compare output hashes to check determinism. Compile with `xcrun swift build --package-path Packages/JellyseerrAPI --scratch-path "$work/build"`, using a fresh `mktemp -d` directory for `work` and a cleanup trap. Use Xcode's Swift toolchain through `xcrun` so the compiler matches the selected SDK.

For telemetry installation-ID changes, run `SeerCoreTests/InstallationIDStoreTests`.
These tests use an in-memory Keychain boundary to cover UUID reuse, local-only
storage, unavailable reads, failed writes, concurrent creation, and invalid stored
values without accessing user credentials. Verify that `app.installation.id` is
added to the shared resource only through the consent-gated telemetry setup.
