## ADDED Requirements

### Requirement: Search playable library titles independently
Search SHALL default to Library and search movies and series on the active Jellyfin server without requiring Jellyseerr. Catalog SHALL preserve existing Jellyseerr search and connection prompts. Switching scopes SHALL retain the query, including after connecting Jellyseerr.

#### Scenario: Library search without Jellyseerr
- **WHEN** a user on iPhone compact width opens Search and enters a title without Jellyseerr configured
- **THEN** matching Jellyfin movies and series appear and open existing library details with playback actions

#### Scenario: Explicit catalog scope
- **WHEN** a user on iPad regular width selects Catalog in Search
- **THEN** the existing catalog search or Jellyseerr connection prompt appears

### Requirement: Search lifecycle and pagination
Library search SHALL debounce input, ignore superseded responses, clear results when the query is empty, expose retry on failure, and allow loading further matches. Returning from details SHALL retain completed search pages. Switching servers or Jellyfin credentials SHALL discard the previous search state and details.

#### Scenario: Superseded response
- **WHEN** a response completes after a newer query or cancellation
- **THEN** it does not replace current results or error state

#### Scenario: More matches
- **WHEN** a user on tvOS loads more matches
- **THEN** the next page is appended without removing existing matches

#### Scenario: Server switch
- **WHEN** a user on iPhone compact width switches servers during search
- **THEN** search returns to Library with an empty query and no results from the previous server


#### Scenario: Return from details
- **WHEN** a user on iPhone compact width opens a library result from a later page and returns
- **THEN** previously loaded results remain available without restarting search

#### Scenario: Same-server reauthentication
- **WHEN** a user on iPad regular width signs in again on the active server through Settings
- **THEN** prior search state is cleared and subsequent searches use the replacement Jellyfin credentials
