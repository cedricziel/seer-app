---
name: verify
description: Verify Seer changes with static checks and isolated builds, including telemetry configuration.
---

Run from the repository root:

1. Run `swiftlint lint --strict --no-cache`, `swiftformat --lint . --cache ignore`, `plutil -lint App/SeerApp/Info.plist`, and `git diff --check`. Separate pre-existing failures from changed-file failures.
2. Generate the Xcode project with `xcodegen generate`. Never edit the generated project directly.
3. Build and test relevant schemes using a temporary directory outside the checkout for DerivedData, package clones, and result bundles. Use a disposable simulator and test credentials. Delete the simulator and temporary directory after verification, including on failure. Do not launch against existing simulator or user data. If isolation is unavailable, report runtime verification as blocked.

For telemetry changes, check that CI and TestFlight workflows inject `OTLP_ENDPOINT`, `OTLP_AUTH_HEADER`, `OTLP_TENANT_ID`, and `OTLP_DATASET_ID` through Secrets.xcconfig into Info.plist. Keep real keys out of logs, fixtures, and version control. Verify traces, logs, and metrics against an explicitly selected deployment and tenant, with diagnostics consent enabled in the disposable app instance.

The build and simulator steps above are unverified with this isolation setup. Report static checks separately from runtime and ingestion verification.
