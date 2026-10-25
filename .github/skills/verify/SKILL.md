---
name: verify
description: Verify Seer changes with static checks and isolated builds, including telemetry configuration.
---

Run from the repository root:

1. Run `swiftlint lint --strict --no-cache`, `swiftformat --lint . --cache ignore`, `plutil -lint App/SeerApp/Info.plist`, and `git diff --check`. Separate pre-existing failures from changed-file failures.
2. Generate the Xcode project with `xcodegen generate`. Never edit the generated project directly.
3. For dependency maintenance, run `python3 -m unittest discover -s scripts -p 'test_*.py'` and `actionlint .github/workflows/dependency-audit.yml`. Run `python3 scripts/dependency_audit.py` with authenticated `gh`; exit 1 with a release table means unreviewed newer candidates exist, while an API or parsing error means the audit did not complete.
4. Build and test relevant schemes using a temporary directory outside the checkout for DerivedData, package clones, and result bundles. Use a disposable simulator and test credentials. Delete the simulator and temporary directory after verification, including on failure. Do not launch against existing simulator or user data. If isolation is unavailable, report runtime verification as blocked.

For telemetry changes, check that CI and TestFlight workflows inject `OTLP_ENDPOINT`, `OTLP_AUTH_HEADER`, `OTLP_TENANT_ID`, and `OTLP_DATASET_ID` through Secrets.xcconfig into Info.plist. Keep real keys out of logs, fixtures, and version control. Verify traces, logs, and metrics against an explicitly selected deployment and tenant, with diagnostics consent enabled in the disposable app instance.

Report static checks and simulator results separately from telemetry ingestion verification.

For request notification changes, run [scripts/request-tests.sh](scripts/request-tests.sh). This disposable macOS package tests the real poller, request models, and in-memory SwiftData store with controlled network responses and recorded notification output. It covers approval, decline, media completion with unchanged or completed request status, partial and 4K availability, unchanged polls, legacy cache baselines, and server scoping. It does not verify system notification delivery or app wiring; retain the native build and test checks above.

For server URL resolution changes, run [the isolated resolver tests](../../../.claude/skills/verify/scripts/server-url-tests.sh). The macOS package uses the real resolver and configuration model with stubbed Wi-Fi and reachability, without app data or live servers. Verify the browsing connection gate separately on an isolated simulator.
