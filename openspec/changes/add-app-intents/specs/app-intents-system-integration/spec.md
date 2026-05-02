## ADDED Requirements

### Requirement: SearchMediaIntent conforms to AssistantSchemas.media.search

The system SHALL annotate `SearchMediaIntent` with
`@AssistantIntent(schema: .media.search)` so that Apple Intelligence
and the iOS 18+ system semantic search can include Seer results
inline alongside other registered media providers. The intent's
parameter shape MUST match the schema's expected shape (a search
query string and optional media-type filter).

#### Scenario: Search intent participates in Apple Intelligence semantic search

- **WHEN** the user on iPhone running iOS 18+ asks the system search
  surface for media titles by name
- **THEN** the system MUST be able to dispatch the query to
  `SearchMediaIntent` via the `.media.search` schema and surface
  returned `MediaItemEntity` values inline alongside other providers'
  results

### Requirement: Playback start donates INPlayMediaIntent

The system SHALL donate an `INPlayMediaIntent` interaction every time a
playback session starts successfully against a resumable media item.
The donation MUST be issued from `PlaybackClient` on the same code
path that begins playback. The donation MUST NOT fire for non-resumable
content such as Live TV streams.

#### Scenario: Playback start donates to system

- **WHEN** the user on iPhone starts playback of a movie via
  `PlaybackService.start(item:)` and playback succeeds
- **THEN** the system MUST issue an `INInteraction.donate()` for an
  `INPlayMediaIntent` carrying the played item's identifier and a
  thumbnail, executed within the same async context as the playback
  start

#### Scenario: Live TV streams do not donate

- **WHEN** the user on iPhone starts playback of an item where
  `MediaItem.isResumable == false`
- **THEN** the system MUST NOT donate an `INPlayMediaIntent` for that
  item

### Requirement: SeerFocusFilter pins active server during a Focus mode

The system SHALL provide a `SeerFocusFilter` conforming to
`SetFocusFilterIntent` with a required `ServerEntity` parameter. When
a Focus mode using the filter activates, the system MUST set
`AppState.activeServerID` to the filter's server and remember the
previously active server. When the Focus mode deactivates, the system
MUST restore the previously active server.

#### Scenario: Focus mode pins active server

- **WHEN** the user on iPhone configures a Focus mode "Family Movie
  Night" with `SeerFocusFilter` set to the "Family" server, the user's
  current active server is "Personal", and the Focus mode activates
- **THEN** `AppState.activeServerID` MUST become the id of the
  "Family" server immediately, and any subsequent intent invocation
  MUST resolve `ServerEntity.defaultResult()` to the "Family" server

#### Scenario: Focus mode deactivation restores previous server

- **WHEN** the user on iPhone has the "Family Movie Night" Focus mode
  active with the active server pinned to "Family", and the Focus mode
  deactivates
- **THEN** `AppState.activeServerID` MUST be restored to the value it
  held before the Focus mode activated

#### Scenario: Pinned server is later deleted

- **WHEN** the user on iPhone activates a Focus mode whose
  `SeerFocusFilter` server has been deleted from
  `ServerConfiguration` since the filter was configured
- **THEN** the filter MUST no-op without changing
  `AppState.activeServerID`, MUST NOT throw, and MUST log the
  condition to the OS log subsystem
