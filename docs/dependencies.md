# Dependency maintenance

Dependabot checks Bundler, GitHub Actions, and the JellyseerrAPI Swift package daily.
The weekly Dependency audit workflow checks both Swift lockfiles and the SwiftLint
and SwiftFormat versions pinned in CI, plus the OpenAPI generator and schema
versions documented in the API package guide. Run it manually from GitHub Actions or run
`python3 scripts/dependency_audit.py` locally with an authenticated `gh` CLI.
The job summary lists newer stable releases. Reviewed deferrals are recorded in
`.github/dependency-audit-deferrals.json` with a version and reason. A release newer
than that reviewed version fails the audit; unchanged deferrals remain visible
without repeated alerts. API failures also fail the job. The audit reports candidates, including transitive packages; it does
not prove that the package resolver can select every release.

Refresh the app's packages in a temporary checkout. Generate the project with
XcodeGen, remove both Swift lockfiles and the temporary package workspace state,
and resolve with `xcodebuild -resolvePackageDependencies`. Copy the resolved
lockfiles back after checking the version changes. Keep package clones,
DerivedData, and test results outside the working tree. Follow the project verify
skill for disposable simulator tests.

The Jellyfin SDK is declared as `JellyfinAPI`, but `JellyfinService` currently sends
requests through `URLSession` and decodes app-owned models. Adopting the SDK requires
migrating those requests behind the existing service interface. SDK 1.0 replaced
its API generator; the current SDK 3.x requires a separate compatibility review.

OpenTelemetry upgrades move API/SDK products and exporters together when their
package boundaries change. Verify real in-memory metric collection as well as
compilation: the SDK view registry requires an explicit app histogram view.
Keep dynamic diagnostics export gates and collection preferences intact. No durable
offline span buffer or automatic URLSession instrumentation is enabled.

Resolve with the declared minimum Swift toolchain. The locks retain Collections
1.7.1, CustomDump 1.7.0, and XCTestDynamicOverlay 1.11.0 because their newer releases
require Swift 6.4. Check every selected manifest before resolving with a newer compiler.

SwiftLint 0.65.1 and SwiftFormat 0.64.1 introduce rules that fail existing source.
Their older pins remain deliberate until a separate formatting change passes CI.
Keep CI versions and checksums synchronized with the session hook versions.
