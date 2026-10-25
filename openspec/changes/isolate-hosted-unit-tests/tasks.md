## 1. Tests (red)

- [x] 1.1 Identify the original hosted-test crash in CloudKit startup from the matching process and simulator report.
- [x] 1.2 Run `make lint` and `make format` checks without rewriting unrelated files.

## 2. Implementation (green)

- [x] 2.1 Dispatch injected Debug XCTest to an inert host, addressing 1.1.
- [x] 2.2 Verify the unsigned binary has no entitlement payload and that all 11 native search tests pass on a disposable simulator.
- [x] 2.3 Add the project-local verify skill and source review the entry point.
- [x] 2.4 Run `make lint` and `make format` checks without rewriting unrelated files.
