## ADDED Requirements

### Requirement: Detect Quick Connect availability

The system SHALL query the target Jellyfin server for Quick Connect
availability before offering it as an authentication option. When Quick
Connect is disabled or the endpoint is unreachable, the authentication
view MUST fall back to username/password without a separate user action.

#### Scenario: Server has Quick Connect enabled

- **WHEN** the user on iPhone selects a server whose
  `/QuickConnect/Enabled` endpoint returns `true`
- **THEN** the authentication view MUST present Quick Connect as the
  primary authentication path with username/password available as a
  secondary option

#### Scenario: Server has Quick Connect disabled

- **WHEN** the user on iPhone selects a server whose
  `/QuickConnect/Enabled` endpoint returns `false` or returns a 404
- **THEN** the authentication view MUST present the username/password form
  as the primary path and MUST NOT mention Quick Connect

### Requirement: Quick Connect session lifecycle

The system SHALL implement the full Quick Connect lifecycle in
`JellyfinClient`: initiate a session, expose its code and secret, poll the
state until authenticated or expired, exchange the approved secret for an
access token, and allow caller-initiated cancellation. The session MUST be
modelled as a Swift type with explicit states (`pending`, `approved`,
`expired`, `failed`) consumable by SwiftUI.

#### Scenario: User approves Quick Connect on Jellyfin web

- **WHEN** the user initiates Quick Connect on iPhone, the SDK returns a
  six-character code and secret, and the user enters and approves that
  code on the Jellyfin web client
- **THEN** the next state poll MUST return `approved`, the session MUST
  exchange the secret for an access token, and the session state MUST
  transition to a terminal authenticated state carrying the
  `AccessToken`, `User.Id`, and device identifier

#### Scenario: Code expires without approval

- **WHEN** the Quick Connect code is not approved within the server's
  configured timeout window (default 600 seconds)
- **THEN** the session state MUST transition to `expired`, the polling
  loop MUST stop, and the caller MUST be able to call `restart()` to
  initiate a fresh session

#### Scenario: User cancels Quick Connect

- **WHEN** the user dismisses the Quick Connect view before approval
- **THEN** the session MUST cancel its polling loop, the session MUST
  release any timers, and the session MUST NOT exchange any credential

### Requirement: Quick Connect polling cadence

The system SHALL poll Quick Connect state with backoff: initial polls
every 1 second for the first 30 seconds, then every 3 seconds thereafter
until the session terminates. Polling MUST stop immediately on `approved`,
`expired`, `failed`, or caller cancellation.

#### Scenario: Backoff after 30 seconds

- **WHEN** a Quick Connect session has been polling for 31 seconds without
  reaching a terminal state
- **THEN** the polling interval MUST be 3 seconds (not 1 second)

### Requirement: Inline fallback to password authentication

The system SHALL provide a "Use password instead" affordance on the Quick
Connect view that switches to the username/password form without losing
the selected server context. The reverse affordance ("Use Quick Connect")
MUST appear on the password form when Quick Connect is available.

#### Scenario: User switches from Quick Connect to password

- **WHEN** the user on iPhone is on the Quick Connect view and taps "Use
  password instead"
- **THEN** the view MUST transition to the username/password form for the
  same server with no server URL re-entry required

### Requirement: Quick Connect view accessibility

The Quick Connect view SHALL render the six-character code with type size
that scales to Dynamic Type accessibility sizes (XXL through AX5) without
truncation, MUST expose the code as an accessibility element with custom
spelled-out announcement, and MUST provide a "Copy code" button.

#### Scenario: VoiceOver reads the code character-by-character

- **WHEN** VoiceOver focus lands on the Quick Connect code display on
  iPhone
- **THEN** the announcement MUST spell each character ("4, 7, 3, 8, 1, 9")
  rather than reading "four hundred seventy-three thousand…"
