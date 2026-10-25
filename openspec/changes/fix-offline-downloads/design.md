## Context

DownloadClient delegates background transfers to URLSession and stores files and records per device. Downloads rows expose optional playback callbacks but callers do not provide them. The player finds local files using the active server and reports progress only over the network.

## Goals / Non-Goals

Goals are the four reviewed fixes, regression coverage, and repairing tvOS compilation using supported platform APIs. Changes to transcoding formats, automatic download scheduling, and Library caching are outside this change.

## Decisions

- Put cellular policy on each fresh download request. When resume data carries an incompatible policy, recreate the transfer with the current policy. Keep the existing background session identity to preserve task recovery.
- Validate HTTP status before parking the response body. Delegate failures through the existing retryable failure flow.
- Build a playback destination from the completed Download record. Pass its server key explicitly through native player wrappers so playback does not depend on the active Library or server.
- Save progress to the download store before attempting network synchronization. Keep pending progress in a separate per-device table so deleting media does not discard an unsent update. Match queue row IDs and revisions when acknowledging reports so an older report cannot clear a newer position. Scope each report to its stored server key.
- Retry pending progress when credentials become available, connectivity returns, and the app becomes active. Use JellyfinClient for server reporting and preserve failed records for later attempts.
- Keep the dependency direction features → clients → SeerCore. No new module relationship is required.
- Keep Spotlight indexing and MetricKit subscription on iOS. tvOS retains AppEntity support, standard telemetry, and consent checks without referencing unavailable system types.
- Adapt shared player entry points to TVPlayerView on tvOS. Keep swipe actions and navigation title display modes on iOS; use context menus for tvOS deletion. Show feedback submission instructions on tvOS because its system sharing controller is unavailable.

## HIG & Layout

### iPhone (compact width)

Keep the existing Downloads list and add a standard playback button to completed rows. Present the native player full screen in portrait and landscape. Preserve deletion and transfer controls.

### iPad (regular width)

Use the same adaptive list in regular width and compact split-view widths. The player uses system presentation and aspect-ratio handling; no fixed page width is introduced.

### tvOS

Use a native focusable playback button and AVPlayerViewController. The Siri Remote can activate a completed row and dismiss playback back to Downloads.

### Aspect ratios

Retain native video aspect-ratio handling and safe areas. Downloads content uses the available list width.

### Accessibility

Give playback controls an explicit Play label with the item title. Use system button semantics, scalable text, and existing player controls. Add no custom motion.

### HIG references

- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons): recognizable actions, standard controls, and adequate hit regions.
- [Playing video](https://developer.apple.com/design/human-interface-guidelines/playing-video): native players, familiar remote interactions, and automatic resume at the previous position.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): control sizing, labels, and adaptable presentation.

## Risks / Trade-offs

- Changing a resumed transfer's cellular policy can require restarting from the beginning. Restrict cellular usage before preserving partial bytes.
- Network reporting can fail or overlap local saves. Keep pending revisions until acknowledged and prevent overlapping flushes per server.
- Playback can outlive the visible view through PiP. Capture download identity for the player lifetime and save on pause, stop, and completion.
- Existing records retain saved resume positions. New playback saves enqueue progress in the separate pending table.

## Migration Plan

Add the pending-progress model to the existing per-device container schema. Existing download records retain their metadata and saved positions. Existing background tasks keep the same session identifier. Requests created by previous versions need policy reconciliation when recovered.
