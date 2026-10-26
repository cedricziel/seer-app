## ADDED Requirements

### Requirement: Background transfers enforce the cellular preference

The system SHALL enforce the saved WiFi-only preference at the URLSession request boundary for fresh and resumed downloads, including while the app is suspended. WiFi-only SHALL default to enabled.

#### Scenario: WiFi disappears during background transfer
- **GIVEN** WiFi-only downloads are enabled
- **WHEN** a transfer loses WiFi while the app is suspended
- **THEN** the transfer MUST NOT continue over cellular

#### Scenario: Resume data has an older cellular policy
- **GIVEN** a paused transfer was created with cellular access enabled
- **WHEN** the user resumes it with WiFi-only enabled
- **THEN** the resumed transfer MUST enforce the current cellular restriction

#### Scenario: Cellular downloads are permitted explicitly
- **WHEN** WiFi-only downloads are disabled and a transfer starts or resumes
- **THEN** the request SHALL permit cellular access

### Requirement: HTTP failures cannot become completed downloads

The system SHALL accept only successful HTTP download responses as completed media. Rejected response bodies SHALL NOT enter permanent media storage or produce success notifications, and the download SHALL remain retryable.

#### Scenario: Server rejects a transfer
- **WHEN** a transfer returns HTTP 401, 404, or 500
- **THEN** the system SHALL report a failed download with its HTTP status
- **AND** SHALL NOT publish the response body as completed media

#### Scenario: Successful media response
- **WHEN** a transfer returns HTTP 200 or 206
- **THEN** the system SHALL preserve the downloaded media for finalization

### Requirement: Completed downloads open directly in the player

The system SHALL provide an accessible playback action for completed movies and episodes in Downloads. Playback SHALL use the download's stored item metadata and server identity without requiring a Library cache entry or changing the active server.

#### Scenario: Play a downloaded movie on iPhone
- **WHEN** a user on iPhone compact width activates a completed movie in Downloads while offline
- **THEN** the native player SHALL open the local movie using stored metadata

#### Scenario: Play a downloaded episode on iPad
- **WHEN** a user on iPad regular or compact split-view width activates a completed episode in Downloads
- **THEN** the native player SHALL open that episode with its stored resume position

#### Scenario: Play from another server on Apple TV
- **GIVEN** a completed download belongs to a server other than the active server
- **WHEN** a user on tvOS regular width focuses and activates its playback action
- **THEN** the native player SHALL use the downloaded file associated with the stored server

#### Scenario: Incomplete downloads cannot be played
- **WHEN** a download is pending, downloading, paused, waiting for WiFi, failed, or lacks a stored file path
- **THEN** Downloads SHALL NOT offer playback for that record

### Requirement: Downloaded playback persists progress locally

The system SHALL persist resume position and watched status in per-device storage during downloaded playback, including periodic reporting, seeking, pausing, and stopping. Subsequent playback SHALL use the saved local position. Completion SHALL mark the download watched.

#### Scenario: Pause and reopen offline
- **WHEN** a user watches a downloaded item offline, pauses, dismisses, and opens it again
- **THEN** playback SHALL resume from the locally saved position

#### Scenario: Finish offline
- **WHEN** downloaded playback reaches completion while offline
- **THEN** the system SHALL persist the watched status locally

### Requirement: Pending progress synchronizes without losing newer updates

The system SHALL retain pending downloaded playback progress until the matching server accepts it. It SHALL retry on reconnect, foreground activation, or credential configuration. Synchronization SHALL preserve updates saved while an older report is in flight and SHALL NOT change favorites.

#### Scenario: Failed synchronization retries
- **WHEN** reporting pending progress fails
- **THEN** the local progress SHALL remain available for a later retry

#### Scenario: Server identity isolates pending progress
- **WHEN** the active server reconnects
- **THEN** only progress belonging to that server SHALL be reported with its credentials

#### Scenario: New progress arrives during synchronization
- **GIVEN** a progress report is in flight
- **WHEN** a newer local position is saved before the report succeeds
- **THEN** the newer position SHALL remain pending

#### Scenario: Media is deleted before reconnecting
- **GIVEN** downloaded playback has saved pending progress while offline
- **WHEN** the user deletes the downloaded media before reconnecting
- **THEN** the pending progress SHALL survive media deletion and synchronize with its original server
