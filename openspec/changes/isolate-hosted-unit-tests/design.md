## Context

SeerApp.init unconditionally opens a private CloudKit store. An unsigned simulator test host lacks iCloud entitlements.

## Goals / Non-Goals

Allow hosted tests to execute without production state or services. Keep normal app startup unchanged.

## Decisions

Select HostedUnitTestApp before constructing SeerApp when Debug startup detects the injected XCTestCase class. A minimal host avoids all production initialization, including the delegate adaptor. Changing only the store configuration would leave other production services active.

## HIG & Layout

N/A — non-UI change (the inert host is only used by injected unit tests).

## Risks / Trade-offs

The XCTest class must be loaded before main. A controlled unsigned native test run confirmed that path. UI tests use a separate runner process.
