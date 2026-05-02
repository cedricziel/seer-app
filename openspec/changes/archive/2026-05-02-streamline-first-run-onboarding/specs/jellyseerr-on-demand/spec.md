## ADDED Requirements

### Requirement: Connect-on-demand prompt on Discover

The Discover tab SHALL render a connect-on-demand prompt when the active
server has no Jellyseerr URL configured. The prompt MUST use
`ContentUnavailableView` styling, MUST explain what Jellyseerr unlocks,
and MUST offer a single primary action that opens the Jellyseerr connect
sheet.

#### Scenario: Discover tab opened without Jellyseerr

- **WHEN** the user on iPhone compact width opens the Discover tab and
  the active `ServerConfiguration.jellyseerrURL` is nil
- **THEN** Discover MUST render a `ContentUnavailableView` titled
  "Discover Movies & Shows" with a "Connect Jellyseerr" primary action,
  and MUST NOT issue any network requests against Jellyseerr

#### Scenario: Successful connect refreshes Discover

- **WHEN** the user completes the Jellyseerr connect sheet from Discover
- **THEN** the Discover view MUST automatically reload its content using
  the new credentials without requiring a tab switch or manual pull-to-
  refresh

### Requirement: Connect-on-demand prompt on Requests

The Requests tab SHALL render the same connect-on-demand prompt pattern
when Jellyseerr is not configured.

#### Scenario: Requests tab opened without Jellyseerr

- **WHEN** the user on iPhone opens the Requests tab and Jellyseerr is
  not configured
- **THEN** Requests MUST render a `ContentUnavailableView` titled
  "Manage Requests" with a "Connect Jellyseerr" primary action

### Requirement: Connect prompt on Search "Request" action

The system SHALL present the Jellyseerr connect sheet, rather than
executing the request action, when the user taps a "Request" affordance
on a search result and Jellyseerr is not configured. After a successful
connect, the original request action MUST proceed automatically.

#### Scenario: Tapping Request without Jellyseerr opens the sheet

- **WHEN** the user on iPhone taps "Request" on a search result and
  Jellyseerr is not configured
- **THEN** the Jellyseerr connect sheet MUST be presented, and the
  underlying request flow MUST NOT proceed

#### Scenario: Successful connect resumes the request

- **WHEN** the user completes the Jellyseerr connect sheet originating
  from a "Request" tap on a specific search result
- **THEN** the system MUST automatically proceed with the request flow
  for that same search result without requiring a second tap

### Requirement: Reusable Jellyseerr connect sheet

The system SHALL expose a reusable `JellyseerrConnectSheet` in `SeerUI`
summonable from any feature surface. The sheet MUST collect the
Jellyseerr URL and API key, MUST validate the credentials by calling
`JellyseerrService.verifyAuth()` before dismissing, MUST persist URL and
API key on success via the same `AppState` paths used today, and MUST
emit a completion result the caller can react to.

#### Scenario: Sheet validates credentials before dismissing

- **WHEN** the user enters a Jellyseerr URL and API key in the sheet and
  taps Connect
- **THEN** the sheet MUST call `verifyAuth()` and MUST display an inline
  error if the call fails, without dismissing or persisting credentials

#### Scenario: Sheet persists credentials on successful auth

- **WHEN** `verifyAuth()` succeeds inside the connect sheet
- **THEN** the active `ServerConfiguration.jellyseerrURL` MUST be updated,
  the API key MUST be stored in Keychain via
  `AppState.saveJellyseerrCredentials`, and the sheet MUST dismiss with a
  success completion the caller observes

### Requirement: "Maybe later" dismisses the sheet without side effects

The Jellyseerr connect sheet SHALL provide a "Maybe later" / Cancel
affordance that dismisses the sheet without persisting any state or
modifying the server configuration.

#### Scenario: User dismisses the sheet

- **WHEN** the user on iPhone opens the Jellyseerr connect sheet from
  Discover and taps "Maybe later"
- **THEN** the sheet MUST dismiss, no Keychain entry MUST be written, the
  server configuration MUST be unchanged, and the Discover tab MUST
  continue showing the connect-on-demand prompt

### Requirement: Onboarding flow does not require Jellyseerr

The first-run onboarding flow SHALL NOT request Jellyseerr credentials
nor display a Jellyseerr setup step. `markOnboardingComplete()` MUST be
callable with only Jellyfin credentials configured.

#### Scenario: Fresh user finishes onboarding without Jellyseerr

- **WHEN** the user completes the streamlined onboarding on iPhone
  without ever seeing or interacting with Jellyseerr
- **THEN** `OnboardingManager.hasCompletedOnboarding` MUST be true and
  `appState.isAuthenticated` MUST be true
