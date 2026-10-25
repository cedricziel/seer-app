# Dependency maintenance

Dependabot checks Bundler, GitHub Actions, and the JellyseerrAPI Swift package daily.
The weekly Dependency audit workflow checks both Swift lockfiles and the SwiftLint
and SwiftFormat versions pinned in CI. Run it manually from GitHub Actions or run
`python3 scripts/dependency_audit.py` locally with an authenticated `gh` CLI.
A failed audit lists newer stable releases in the job summary. API failures also
fail the job. The audit reports candidates, including transitive packages; it does
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

OpenTelemetry 2.x changes metrics APIs. Later 2.x releases also move core products
into `opentelemetry-swift-core`. Upgrade the package declarations and telemetry
implementation together, and verify consent and export behavior. OpenTelemetry
1.17.1 pins gRPC Swift to 1.26.1, so its newer minor release cannot resolve yet.

SwiftLint 0.65.1 and SwiftFormat 0.64.1 introduce rules that fail existing source.
Their older pins remain deliberate until a separate formatting change passes CI.
Keep CI versions and checksums synchronized with the session hook versions.
