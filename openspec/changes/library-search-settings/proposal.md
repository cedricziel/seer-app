## Why

Search currently requires Jellyseerr and cannot find playable library titles. App-wide preferences are hidden under server management.

## What Changes

- Default Search to the active Jellyfin library, with an explicit Catalog scope for existing Jellyseerr search.
- Open library results in the existing media detail and playback journey.
- Add a labeled Settings toolbar entry on every tab, grouping servers, downloads, privacy, and feedback.
- Keep the five tabs and quick server switcher.

## Capabilities

### New Capabilities

- `library-search`: Debounced, paginated search of the active Jellyfin server without Jellyseerr.
- `app-settings`: Predictable access to app-wide preferences from every primary destination.

### Modified Capabilities

None.

## Impact

Both iOS and tvOS. Search uses JellyfinClient; Catalog retains JellyseerrClient. Features continue to depend on clients and SeerCore. No data migration or new dependencies.
