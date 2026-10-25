## ADDED Requirements

### Requirement: System integrations use supported platform APIs

The application SHALL compile for iOS and tvOS without referencing unavailable system APIs. Spotlight indexing and MetricKit subscription SHALL be included only on iOS. AppEntity support, standard telemetry, and diagnostics consent checks SHALL remain available on tvOS.

#### Scenario: Build Apple TV application
- **WHEN** the application is compiled against the tvOS SDK
- **THEN** unsupported Spotlight and MetricKit types SHALL be excluded
- **AND** media and request entities SHALL retain their AppEntity conformance

#### Scenario: Preserve iOS integrations
- **WHEN** the application is compiled against the iOS SDK
- **THEN** media and request entities SHALL retain IndexedEntity conformance
- **AND** Spotlight indexing and consent-gated MetricKit subscriptions SHALL remain available

### Requirement: Shared playback entry points use the native television player

The system SHALL route shared media playback entry points to TVPlayerView on tvOS while preserving item identity, download server identity, resume position, and dismissal behavior.

#### Scenario: Play downloaded media on Apple TV
- **WHEN** a user on tvOS regular width activates playback for a completed download
- **THEN** the native television player SHALL open that download at its saved position
- **AND** dismissing playback SHALL return to the originating view

### Requirement: Television controls use supported interactions

The system SHALL keep navigation title display modifiers and swipe actions off tvOS. Downloads and recent searches SHALL provide focusable context-menu alternatives for deletion.

#### Scenario: Delete a download on Apple TV
- **WHEN** a user on tvOS regular width opens a download's context menu
- **THEN** a Delete action SHALL remain available

#### Scenario: Remove a recent search on Apple TV
- **WHEN** a user on tvOS regular width opens a recent search's context menu
- **THEN** a Remove action SHALL remain available

### Requirement: Feedback explains available submission platforms

The system SHALL present feedback submission instructions on tvOS without offering editable fields that cannot be submitted. The iOS feedback form and sharing behavior SHALL remain available.

#### Scenario: Open feedback on Apple TV
- **WHEN** a user on tvOS regular width opens Send Feedback
- **THEN** the system SHALL direct the user to submit feedback from Seer on iPhone or iPad
- **AND** SHALL NOT present an editable feedback form without a submission action
