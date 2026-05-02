# server-onboarding Specification

## Purpose
TBD - created by archiving change streamline-first-run-onboarding. Update Purpose after archive.
## Requirements
### Requirement: State-aware welcome screen on launch

When the user is unauthenticated, the system SHALL present a welcome screen
whose primary suggestion is computed from initial state: existing iCloud
server configurations, Bonjour-discovered servers on the current Wi-Fi, or
nothing (fresh-install fallback). The welcome screen MUST always offer a
manual URL entry escape hatch.

#### Scenario: Fresh install with no iCloud and no Bonjour hits

- **WHEN** the user on iPhone compact width launches the app for the first
  time and there are no iCloud-synced `ServerConfiguration` records and the
  Bonjour browser has emitted zero hits within 1.5 seconds
- **THEN** the welcome screen MUST render the manual URL entry call-to-
  action as the primary action and MUST NOT show a "Re-authenticate" or
  "Use this server" suggestion

#### Scenario: iCloud has a synced server

- **WHEN** the user on iPhone compact width launches a freshly installed
  app on a device signed into the same iCloud account that has at least
  one synced `ServerConfiguration`
- **THEN** the welcome screen MUST render the synced server as the primary
  suggestion ("Sign back in to <name>") with the manual entry path
  available below it

#### Scenario: Bonjour finds a server on the current Wi-Fi

- **WHEN** the user on iPhone compact width launches the app, has no
  iCloud-synced configurations, and the Bonjour browser emits at least one
  `_jellyfin._tcp` hit within 1.5 seconds
- **THEN** the welcome screen MUST render the discovered server as the
  primary suggestion ("Use <hostname> on this Wi-Fi"), MUST list any
  additional discovered servers below it, and MUST keep manual entry
  available

#### Scenario: tvOS focus engine on welcome screen

- **WHEN** the user on tvOS launches the app for the first time
- **THEN** the welcome screen MUST place initial focus on the primary
  suggestion and MUST be navigable end-to-end with the Siri Remote
  directional pad

### Requirement: Authentication leads straight into the Library tab

The system SHALL transition directly to `MainTabView` with the Library
tab active after a successful server authentication during onboarding.
It MUST NOT present an interstitial "Setup Complete" celebration screen.
`OnboardingManager.markOnboardingComplete()` MUST be called once before
the transition so What's New gating and first-run-tip behavior remain
intact.

#### Scenario: Successful authentication routes to Library

- **WHEN** the user completes Quick Connect or password authentication
  during onboarding on iPhone
- **THEN** the next visible screen MUST be `MainTabView` with the Library
  tab selected, and `OnboardingManager.hasCompletedOnboarding` MUST be true

#### Scenario: First-run tip still appears after streamlined flow

- **WHEN** the user completes onboarding via the streamlined flow on iPhone
  and arrives on the Library tab for the first time
- **THEN** `OnboardingManager.isFirstLaunchAfterSetup` MUST be true and the
  first-run tip on `LibraryView` MUST render

### Requirement: Library pre-warm during authentication wait

The system SHALL pre-warm the library cache while the user waits for
Quick Connect approval (between code display and authenticated callback)
so that the Library tab is not empty on first display. Pre-warming MUST
be opportunistic and MUST NOT block the authentication completion
handler.

#### Scenario: Quick Connect polling pre-warms libraries

- **WHEN** Quick Connect has issued a code and the user has not yet
  approved it on the Jellyfin web client
- **THEN** the system MAY issue authenticated requests for libraries and
  the "Continue Watching" feed using a temporary token if available, OR
  defer pre-warm until the access token is issued; pre-warm completion
  MUST NOT delay the navigation to the Library tab

#### Scenario: Pre-warm failure does not block onboarding

- **WHEN** library pre-warm fails for any reason during the Quick Connect
  wait
- **THEN** onboarding completion MUST proceed unchanged and the failure
  MUST be surfaced only as a normal Library load error after the user
  arrives on the tab

### Requirement: Manual URL entry path

The system SHALL provide a manual URL entry path reachable from the
welcome screen at all times. The manual entry view MUST accept a
Jellyfin URL, validate it as a reachable Jellyfin server before
proceeding, and route to the same authentication step as the
Bonjour and iCloud paths.

#### Scenario: Valid URL with reachable Jellyfin server

- **WHEN** the user on iPhone enters a URL pointing to a reachable
  Jellyfin server and taps Continue
- **THEN** the system MUST advance to the authentication step

#### Scenario: URL is not a Jellyfin server

- **WHEN** the user enters a URL that responds successfully but does not
  expose `/System/Info/Public` with Jellyfin server identification
- **THEN** the system MUST display an inline error explaining that the URL
  does not look like a Jellyfin server and MUST NOT advance

### Requirement: Onboarding errors stay on the welcome screen

The system SHALL surface authentication and discovery errors inline on the
welcome screen or its child entry views. Onboarding MUST NOT pop the user
back to a generic error alert that loses their entered context.

#### Scenario: Quick Connect timeout

- **WHEN** the Quick Connect code expires without user approval
- **THEN** the system MUST display an inline message on the Quick Connect
  view ("Code expired — try again") with a button to request a new code,
  and MUST preserve the previously selected server

#### Scenario: Manual URL entry fails

- **WHEN** the user enters a URL that returns a connection error
- **THEN** the system MUST display the error inline on the manual entry
  view with retry guidance and MUST preserve the entered URL

