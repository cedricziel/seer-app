---
name: verify
description: Verify Seer changes, including regeneration and compilation of the checked-in OpenAPI client.
---

# Verify Seer changes

Run commands from the repository root. For API changes, follow the pinned generator
setup in [the API package guide](../../../Packages/JellyseerrAPI/README.md).
Regenerate twice and compare the output hashes to check determinism. Compile the
API package with `xcrun swift build --package-path Packages/JellyseerrAPI
--scratch-path "$work/build"`, where `work` is a fresh `mktemp -d` directory.
Remove the temporary directory when finished, including after failure.

Run `swiftformat --lint .` and `make lint` for Swift changes. Generated API files
are excluded by the repository configuration.

For app behavior changes, use an isolated simulator, DerivedData directory, test
credentials, and test destinations. Do not launch against existing user data.
Select relevant tests from the SeerApp scheme. Simulator execution is unverified
by this skill; if isolation cannot be established, report that limitation.
