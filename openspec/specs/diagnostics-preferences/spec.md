# Diagnostics preferences

## Purpose

Provide limited reliability diagnostics under the documented legitimate-interest
assessment, with device-local category controls and preserved existing choices.

## Requirements

### Requirement: Diagnostics default to enabled without an upfront prompt

The app SHALL enable crash and performance diagnostics when no saved preference
or legacy declined choice exists. It MUST NOT present a diagnostics consent sheet.

#### Scenario: Fresh installation

- **WHEN** a fresh installation starts on iOS, tvOS, or macOS
- **THEN** both diagnostics categories SHALL be enabled without a consent modal
- **AND** Privacy settings SHALL explain the default and provide category controls

### Requirement: Existing opt-outs remain disabled

A saved false preference MUST remain false. A missing category value after a
legacy recorded consent choice MUST remain disabled.

#### Scenario: Upgrade after declining diagnostics

- **WHEN** an installation with an existing disabled category upgrades
- **THEN** that category MUST remain disabled across launches

### Requirement: Settings opt-outs control collection and export

The app SHALL persist crash and performance preferences independently. Event
creation and export batches MUST check the corresponding current preference.
In-flight network requests MAY finish after a preference changes.

#### Scenario: Disable performance diagnostics after startup

- **WHEN** the user disables performance diagnostics in Privacy settings
- **THEN** new onboarding events and metric recordings MUST stop
- **AND** subsequent performance export and flush calls MUST drop their data
- **AND** crash diagnostics SHALL retain their independent setting

### Requirement: Disclose retention and installation correlation

Privacy settings and the privacy policy SHALL disclose a random installation ID,
30-day report retention, and category opt-outs. The shared resource MUST omit the
vendor device identifier and use only the app-owned local installation ID.

#### Scenario: Inspect diagnostic identity

- **WHEN** Privacy settings opens with an existing Keychain installation ID
- **THEN** the app SHALL display that ID without generating a new one
- **AND** tvOS MUST NOT use unavailable text-selection APIs
