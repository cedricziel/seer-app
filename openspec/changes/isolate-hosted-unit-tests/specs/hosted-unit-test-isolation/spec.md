## ADDED Requirements

### Requirement: Hosted unit tests bypass production initialization
Debug app startup SHALL use an inert SwiftUI host when XCTest is injected into the app process. It SHALL NOT construct SeerApp, initialize its CloudKit stores, or start its production services. Ordinary launches and Release builds SHALL retain production startup.

#### Scenario: Unsigned hosted unit tests
- **WHEN** Xcode launches a Debug app host with injected XCTest and CODE_SIGNING_ALLOWED=NO
- **THEN** hosted unit tests execute without initializing the production CloudKit container

#### Scenario: UI test application startup
- **WHEN** XCTest runs in a separate UI test runner and launches the application
- **THEN** the application retains its production startup path
