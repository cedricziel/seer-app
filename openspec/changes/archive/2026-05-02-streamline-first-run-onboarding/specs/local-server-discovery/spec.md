## ADDED Requirements

### Requirement: Browse Jellyfin services on the local network

The system SHALL provide a Bonjour browser that discovers Jellyfin servers
advertising the `_jellyfin._tcp` service type on the current network. The
browser MUST be exposed as an `@MainActor` `ObservableObject` from
`JellyfinClient` with a `@Published` array of discovered servers. The
browser MUST stop discovery when the caller releases its reference.

#### Scenario: Browser emits discovered server within 1.5 seconds

- **WHEN** the app launches on iPhone connected to a Wi-Fi network with one
  Jellyfin server advertising `_jellyfin._tcp`
- **THEN** the browser's published array MUST contain at least one entry
  with a non-empty `host` and resolvable `URL` within 1.5 seconds of the
  browser starting

#### Scenario: Browser stops on deinit

- **WHEN** the welcome screen is dismissed and the `BonjourDiscovery`
  reference is released
- **THEN** the underlying `NWBrowser` MUST be cancelled and MUST NOT
  continue emitting events

### Requirement: Local network permission surfaced to the caller

The system SHALL expose the iOS local network permission state through the
browser. When the user denies the permission, the browser MUST emit an
empty discovery list and MUST publish a `permissionDenied` flag the
welcome screen can read.

#### Scenario: Permission denied on first browse

- **WHEN** the user denies the iOS Local Network permission prompt the
  first time the browser starts on iPhone
- **THEN** the browser's `discoveredServers` MUST be empty and
  `permissionDenied` MUST be true; the welcome screen MUST fall back to
  the manual entry path without showing a "no servers found" error that
  blames the network

#### Scenario: Permission granted

- **WHEN** the user grants the Local Network permission and at least one
  Jellyfin server is reachable
- **THEN** within 1.5 seconds the browser MUST publish at least one
  discovered server and `permissionDenied` MUST be false

### Requirement: Discovered server identity

Each discovered server entry SHALL carry a stable identity (`name`,
`host`, `port`, resolved `URL`) suitable for display and for use as the
LAN URL when the user accepts the suggestion.

#### Scenario: Resolved server populates internalJellyfinURL on acceptance

- **WHEN** the user taps a Bonjour-discovered server on the welcome
  screen and authentication succeeds
- **THEN** the resulting `ServerConfiguration` MUST have
  `internalJellyfinURL` set to the resolved Bonjour URL

### Requirement: Discovery is cancellable

The system SHALL allow the caller to start and stop discovery
imperatively. Repeated `start()` calls MUST be idempotent.

#### Scenario: Restart after stop

- **WHEN** the welcome screen calls `stop()` then `start()` again on the
  same browser instance
- **THEN** the browser MUST resume publishing discovered servers without
  requiring a new permission prompt
