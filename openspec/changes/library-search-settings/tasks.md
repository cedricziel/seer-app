## 1. Tests (red)

- [x] 1.1 Add search tests for library results without Jellyseerr, blank queries, errors/retry, superseded responses, cancellation, and pagination.
- [x] 1.2 Run the tests before implementation; record environment blockers separately from assertion failures.
- [x] 1.3 Run `make lint` and `make format` checks without rewriting unrelated files.

## 2. Implementation (green)

- [x] 2.1 Add the library search model and SearchTerm support in JellyfinClient, making 1.1 pass.
- [x] 2.2 Default Search to Library with an explicit Catalog scope and existing library detail navigation; reset on server switch, making 1.1 pass.
- [x] 2.3 Add Settings from every tab and move privacy/help out of server management; manually check Settings and existing preferences scenarios.
- [x] 2.4 Run `make lint` and `make format` checks without rewriting unrelated files.

## 3. HIG verification

- [ ] 3.1 Check iPhone compact portrait/landscape and Dynamic Type AX5.
- [ ] 3.2 Check iPad regular and split-view 1/3, 1/2, 2/3.
- [ ] 3.3 Check tvOS focus through Settings, scope, results, and Load More.
- [ ] 3.4 Check VoiceOver order, Reduce Motion, Increase Contrast, and Smart Invert.
- [x] 3.5 Run `make lint` and `make format` checks without rewriting unrelated files.

## 4. Review and verification

- [x] 4.1 Run IA/scope, correctness, and platform/accessibility review agents and address findings.
- [x] 4.2 Validate changed specs and add a project-local verify skill.
- [x] 4.3 Run relevant tests and build with isolated files and simulator data; record unavailable checks.
- [x] 4.4 Run `make lint` and `make format` checks without rewriting unrelated files.

## Verification notes

- The isolated verify script passed all 11 tests against the production model and media types. Removing completed-query preservation from a temporary copy made its regression test fail.
- The initial native test-build attempt began before the new model was registered in the generated project. It failed to compile missing new views; no red XCTest assertion run was observed then.
- The regenerated iOS app and test targets compiled successfully. The supplied crash report later confirmed that native execution crashed during CloudKit initialization in the unsigned hosted app. The earlier startup-stall diagnosis was incomplete.
- Review agents checked IA/scope, correctness, and platform/accessibility source. All actionable findings were addressed and re-reviewed.
- OpenSpec strict validation passed.
- After porting onto current main, repository-wide checks pass with the CI-pinned SwiftLint 0.63.2 and SwiftFormat 0.61.1. All 11 isolated search-model tests pass.
- Compact Search and Settings snapshots were recorded and visually inspected. Other HIG checks remain unverified on devices.
- tvOS compilation is blocked by existing AppIntents/CoreSpotlight code in SeerCore: IndexedEntity is missing and CSSearchableItem/attribute APIs are unavailable on tvOS. These files are unchanged.


Hosted startup isolation is a prerequisite in the separate `isolate-hosted-unit-tests` change.
