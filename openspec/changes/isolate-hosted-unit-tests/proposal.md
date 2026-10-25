## Why

Unsigned hosted unit tests initialize the production CloudKit store and crash before tests execute.

## What Changes

- Select an inert SwiftUI host in Debug when XCTest is injected.
- Preserve ordinary and Release startup.
- Add project-local verification guidance.

## Capabilities

### New Capabilities

- `hosted-unit-test-isolation`: Bypass production initialization for hosted unit tests.

### Modified Capabilities

None.

## Impact

iOS and tvOS entry-point dispatch. No networking or data migration changes.
