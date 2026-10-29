# Platform UX reviews, 2026-10-28

Requested order: iPad, native Mac, tvOS. Revision: `357cfd6`.

## Progress

- Reviewed with limitations: iPad Pro 11-inch, iOS 27.0. Movie, show, season, episode, rotation, and failed-player paths exercised.
- Reviewed with limitations: native Mac. Library and Settings layout defects recorded; movie and episode playback failed.
- Deferred by user: authenticated tvOS review. Both user and automation could not enter a colon in the simulator keyboard. Onboarding visual coverage only.
- In progress: file the reviewed findings as GitHub issues, then implement and review fixes toward release.

Planned coverage includes movies and movie details, shows, seasons and episode
details, library navigation, search, downloads, settings, and playback where
supported. Actual coverage and blocked checks are recorded per platform. Short
playback samples may update server playback progress. Do not submit requests or
change library state.

## Layout matrix

- iPad: portrait, landscape, and a narrow app window where simulator windowing
  supports it. Inspect movie details, show details, season controls, and episode
  details in each layout. Record measured viewport sizes and unavailable modes.
- Mac: compact, wide, and tall native windows. Repeat sidebar, grid, movie,
  show, season, and episode navigation after resizing.
- tvOS: 1080p and 4K simulator presentations. Check remote focus, row edges,
  action labels, and detail readability. Resolution changes alone may preserve
  the same logical aspect ratio; record logical dimensions and avoid claiming
  distinct aspect-ratio coverage from pixel count alone.

## Player matrix

The user explicitly requested player experience coverage after the initial plan.

- Common: start, pause/resume, seek, audio/subtitle menus, full-screen entry/exit,
  control readability, and return navigation.
- iPad: rotate during playback, resize where supported, and picture-in-picture.
- Mac: resize and full-screen transitions, plus available keyboard controls.
- tvOS: remote focus, pause/play, seeking, timeline navigation, and dismissal.
- Inspect route-selection UI where available without choosing a casting device.
  Casting-device playback and offline downloads are outside this pass.
- Mark buffering, playback errors, track switching, and restoration as tested only
  when they are actually exercised. Use short samples and record media type and
  playback path without saving private account or watch-history screenshots.

## Stream-selection investigation

Requested by the user after iPad playback failed.

- Record source container, video/audio codecs, bit depth, resolution, bitrate,
  selected audio/subtitle tracks, and the device profile sent to Jellyfin.
- Compare advertised direct-play/direct-stream/transcode capability with the
  path chosen by PlaybackService and StreamURLBuilder.
- Inspect the actual HLS manifest output codecs and segment format, rather than
  assuming requested codec parameters describe what the server returned.
- Separate playback-info, master/media playlist, and segment request failures.
  Record HTTP status and sanitized error context. Check whether authorization
  survives playlist/segment URLs and redirects without exposing access tokens.
- Check audio compatibility, subtitle burn-in/remux decisions, and appropriate
  platform-specific resolution/bitrate limits. Record native-simulator limitations.
- Current observation: one episode and one H264/EAC3/MKV movie reached an HLS
  NSURLErrorDomain -1013 error. The installed Apple SDK defines -1013 as
  NSURLErrorUserAuthenticationRequired. This identifies the error category, not
  the failing HLS request or server-side cause. Root cause is unconfirmed. Do not classify this
  as a codec failure or claim successful playback.

### Source findings awaiting live-stream verification

- The advertised profile includes MKV direct play and AV1 video, while
  `StreamURLBuilder.isIOSCompatible` rejects MKV and AV1. The server and client
  therefore use different capability rules. This is a confirmed source mismatch,
  not a confirmed explanation of the playback error.
- PlaybackService uses one `Seer iOS` profile with a 120 Mbps streaming ceiling
  for Apple platforms. Verify hardware/platform-specific capabilities and user
  bandwidth settings before judging the selected path appropriate.
- The player constructs `AVPlayerItem(url:)` and relies on URL authentication.
  Although StreamInfo includes headers, this creation path does not use them.
  Initial URL authentication does not establish that nested HLS requests retain it.
  Capture sanitized request outcomes before choosing a fix.

## iPad

Tested a signed Debug build from a temporary source copy with empty
Secrets.xcconfig, isolated package checkouts and DerivedData, and a disposable
iPad Pro 11-inch simulator on iPadOS 27.0. Build passed with arm64 and two jobs.
The user signed in directly. Device: `DC104C0A-2D32-4B94-AADE-7A9A3ABD5B9A`.

### Observed iPad findings

| ID | Priority | Layout | Observation | Suggested change |
| --- | --- | --- | --- | --- |
| IP01 | P2 | Portrait, 1668 × 2420 screenshot pixels | Welcome uses a two-column arrangement with the hero midway down the left, the empty-server message at the upper right, and Enter Server URL at the lower right. The related instructions and action are separated by most of the screen height. | Use a vertically grouped, width-limited welcome composition in portrait, or align the explanatory content and action within the same region. |
| IP02 | P2 | Portrait and landscape | Opening the TV library with All selected mixes Series, Season, and Episode items into the same grid. Generic episode names repeat without show/season context. | Restrict the TV library landing grid to series, or provide a clearly separated episode view with context. |
| IP03 | P2 | Portrait and landscape | The detail pane remains present with no selection, showing Select a Title and compressing the browsing grid. Portrait still uses a three-column grid inside a narrow leading pane. Landscape adds the app navigation sidebar as a third column. | Let browsing use the available width before selection. Provide a detail dismissal/collapse control and use a navigation push or sheet at narrow widths. |
| IP04 | P3 | Show details in both orientations | The series header displays a duration of 0 min. | Omit unknown/non-applicable series runtime or show useful season/episode metadata. |
| IP05 | P2 | Movie details in landscape | Download still breaks into Down- / load beside Play despite the larger overall display. | Give the action an intrinsic minimum width or stack actions when the detail column cannot fit both labels. Reproduces iPhone finding R06. |
| IP06 | P2 | Episode and movie player | Playback fails with raw HLS/NSURLErrorDomain -1013 text. Retry repeats the failure, with no plain-language cause or targeted recovery advice. | Translate the failure into actionable user copy and retain diagnostic codes separately. Investigate the underlying playback/authentication failure independently. |
| IP07 | P2 | Player error after rotation to portrait | Native Play and skip controls overlap the custom Playback Error message. | Hide or disable native playback controls while the error overlay is presented. |

### Signed-in coverage and limitations

- Portrait: opened TV library, inspected two show detail screens, changed from
  season 1 to season 2, verified the selected trait and episode list update, and
  opened an episode detail sheet with title, duration, air date, overview, Play,
  and Download.
- Landscape: rotated with the episode sheet open. The sheet remained usable.
  Closed a failed episode player and returned to the selected season. Opened
  the movie library and a movie detail screen, then attempted movie playback.
- Player: episode start and one Retry failed with HLS error -1013. A movie start
  reached the same error. Do not claim successful streaming, pause/resume, seek,
  track selection, PiP, or playback restoration from these attempts.
- Narrow app window: resize-handle drag had no effect and Device Hub Resize mode was disabled. Narrow-width behavior remains unverified.
- Search: recovered simulator keyboard input, searched a known title, saw matching movie results, and opened movie details. A deliberately corrected duplicate query also exercised No Library Results.
- Downloads/settings: opened No Downloads and Download Settings. Reproduced R04, no start guidance, and R08, unnamed Storage Limit slider exposing 0% for Unlimited. No settings changed or downloads submitted.
- Error evidence: [landscape player error](2026-10-28-platforms/ipad-player-error-landscape.png), [portrait player error](2026-10-28-platforms/ipad-player-error-portrait.png).
- Sanitized simulator log query produced no output before cancellation. No HTTP
  status, failing nested request, or actual manifest codecs were recovered.
- The user explicitly called out the permanent detail pane during this review.
  Source confirms `NavigationSplitView(columnVisibility: .constant(.all))` and
  removal of its sidebar toggle in `Features/Library/LibraryView.swift`.
- Source evidence for IP02: `LibraryViewModel.effectiveIncludeItemTypes` only
  restricts the cross-library Recently Added feed. A selected TV library with
  the All media-type filter passes no item-type restriction to the recursive
  `JellyfinService.getItems` request.

Evidence: [portrait welcome](2026-10-28-platforms/ipad-welcome-portrait.png),
inspected after capture. The installed status-bar name remains Seer while the hero
says Flowmark, reproducing the earlier branding finding. IP01 is a layout usability
observation, not a claim that the primary action is missing or inoperable.

## Mac

The iPad review is complete with the limitations above. Prepared a separate temporary source copy with bundle
identity `test.seer.uxreview.01a18445`, local SwiftData without CloudKit, a unique
non-synchronizing Keychain service, and no production URL-scheme registration.
The UI sources are unchanged. CloudKit and account-status behavior are excluded
from this fixture. The native Mac Debug build passed, original exec `60920` exit 0. Verified the
built bundle identity and App Sandbox entitlement before launch. App opened
successfully and reached Add Server on October 29. The user signed in directly.

### Observed Mac findings

| ID | Priority | View | Observation | Suggested change |
| --- | --- | --- | --- | --- |
| MC01 | P2 | Add Server, initial 1800 × 1304 screenshot | The example URL is rendered outside the input as a blue leading label, while the empty field and Continue stretch to the right window edge. The form lacks a readable maximum width. | Use a prompt inside the field, leading-aligned labels, and a centered form with a bounded width. |
| MC02 | P2 | Add Server, keyboard | User reports Return does not advance after entering a server URL. Source confirms the URL field has no onSubmit handler and Continue has no default keyboard shortcut. | Submit through the same validated Continue action on Return, respecting empty-input and in-progress guards; make Continue the macOS default action. |
| MC03 | P2 | Quick Connect | User reports Copy code does not copy. Source confirms the callback writes only through UIPasteboard under a UIKit/non-tvOS condition; on native macOS the visible button runs an empty callback. | Implement the macOS clipboard path using NSPasteboard and provide copy confirmation after a successful write. |
| MC04 | P1 | Library home, initial and maximized/tall windows | The leading library column measures 144 in the accessibility split value and renders the welcome banner almost letter by letter. The unselected detail pane takes most of the window. Maximizing and left-half tiling preserve the collapsed column. Entering the movie library yields an empty leading grid. | Repair split-column sizing and preserve a usable browsing minimum; allow browsing to fill space before selection. |
| MC05 | P2 | Movie player | Native Mac reproduces the iPad HLS -1013 failure for the same movie. Raw technical text and Retry do not explain recovery; native player controls remain visible behind the error. | Diagnose the failed authenticated HLS request and show actionable error copy with a clean error state. |
| MC06 | P3 | Wide show detail | Episode-row action buttons align at the far right edge of a maximized window, far from their titles, while the list has no readable maximum width. | Bound the detail/list content width and keep row actions near the related episode. |
| MC07 | P1 | Settings | The settings sheet renders only Settings and Done at 940 × 226 screenshot pixels. List rows exist in accessibility but are offscreen; attempting Downloads returns cannotClickOffscreenElement. | Give the macOS settings list a usable minimum height and let the sheet size around visible content. |

The welcome screen repeats R01, Flowmark branding. Add Server repeats R02,
internal-address terminology without context. Evidence: [Mac Add Server](2026-10-28-platforms/mac-add-server.png).

### Signed-in coverage and limitations

- Opened Library home at 1800 × 1304 screenshot pixels, maximized at
  2940 × 1846, and used Window > Move & Resize > Left for a tall
  1602 × 1846 window. These are screenshot pixels, not logical points.
- The collapsed leading pane persisted. Dismissed the welcome notice and opened
  the movie library. It rendered an empty leading grid without visible recovery.
- Search returned known movie matches and opened a full-width movie detail page,
  avoiding the broken library split. Inspected H264 1080p, EAC3 5.1, MKV metadata.
- Started the same movie used on iPad. It failed with HLS -1013. Escape dismissed the player and restored details. Successful playback, seek, track switching, and PiP remain blocked.
- Searched a multi-season show, changed season 1 to season 2, and opened an episode sheet. Escape dismissed it and preserved the selected season. Reproduced IP04, 0 min series runtime, and R07, decorative rating star exposed as Favourite.
- Maximized the show detail and inspected all eight episode rows. Started an episode through its Play accessibility action; it also failed with HLS -1013. Escape returned to season 2.
- Used Window > Move & Resize > Top Left for a compact 1602 × 1306 screenshot. Reopened the movie library; the collapsed empty grid persisted.
- Opened Downloads and Settings. No Downloads repeats R04. Settings contents were visually inaccessible, so download/privacy settings could not be reviewed. Evidence: [collapsed Settings](2026-10-28-platforms/mac-settings-collapsed.png).
- Successful streaming, pause/resume, seek, audio/subtitle switching, PiP, and playback full-screen remain blocked. No casting target, download, request, or destructive account action was submitted.
- Player evidence: [Mac HLS error](2026-10-28-platforms/mac-player-error.png).
- Evidence: [collapsed Mac home](2026-10-28-platforms/mac-library-collapsed.png).
  Only generic welcome/empty-detail content is saved in this image.

## tvOS

tvOS onboarding reviewed with limitations. Disposable Apple TV simulator: `95D25DDB-AFF8-4B8A-8BA5-96B577043D54`, Seer-UX-tvOS-01a18445, tvOS 27.0, Apple TV 4K third generation. The signed arm64 Debug build passed, original exec `51243` exit 0. Installed and launched successfully on the disposable TV, PID 58116. Welcome and server entry review started.


### tvOS checks prompted by source

- TVPlayerView delegates controls and dismissal to AVPlayerViewController.
  Its wrapper does not present VideoPlayerViewModel.errorMessage or a Retry
  action. Verify actual failure presentation before classifying this as a defect.
- Verify back/menu dismissal preserves the originating title and selected season.
- Preflight confirmed remote Select opens the simulator Settings app and Down
  moves the visible focus to the next row. This verifies the input path only,
  not Seer focus behavior.
- The 4K simulator reports a 3840 × 2160 display with preferred UI scale 2.
  Preflight switched to 1920 × 1080 at scale 1 and confirmed Pixel Size and
  Preferred UI Scale, then restored 3840 × 2160 at scale 2. Both modes have a
  1920 × 1080 logical viewport and 16:9 aspect ratio. App review in both modes
  remains pending; do not count this device-mode check as app coverage.

### Observed tvOS findings

| ID | Priority | View | Observation | Suggested change |
| --- | --- | --- | --- | --- |
| TV01 | P1 | Welcome, 4K | The manual-entry action renders as a blank white bar. Its label is unreadable. Remote navigation eventually reached server entry, so this is not proof the action is inoperable. | Use tvOS-aware foreground/background colors and visible focus treatment in the custom button style. |

Evidence: [4K welcome](2026-10-28-platforms/tvos-welcome-4k.png), captured
from the simulator framebuffer and inspected. Reproduces R01 branding mismatch.
Source uses Color.accentColor for the action background and Color.white for
its label without a tvOS-specific treatment.

### tvOS coverage so far

- App launched at 4K and displayed the welcome screen. Remote movement and
  Select eventually opened server URL entry and its native TV keyboard.
- URL entry was corrupted while user and automation both controlled input.
  The user confirmed the interference and requested a retry. The retry also
  exposed a dot/colon mismatch in automated text entry. No product URL-validation
  defect is established. Direct URL correction and sign-in are still required.
- Switched to actual 1080p at scale 1 and observed Add Server with its URL field and Continue action. No authenticated tvOS library, detail, or player coverage yet. Welcome comparison at 1080p is not complete.
- Preserve the disposable TV and signed-in iPad/Mac fixtures while the requested
  review is unfinished. Cleanup remains due after the final pass.

### Deferred TV sign-in

The user could not select a colon in the simulator keyboard and explicitly
requested skipping tvOS for now. Track URL-entry operability as a simulator
walkthrough blocker requiring a clean physical-remote or simulator reproduction.
Authenticated TV browsing and playback remain untested.

## Tracked follow-up

- [Restore usable library browsing on iPad and native Mac](https://github.com/cedricziel/seer-app/issues/118), IP03, MC04.
- [Give native Mac Settings a usable sheet size](https://github.com/cedricziel/seer-app/issues/119), MC07.
- [Repair server entry layout and keyboard submission](https://github.com/cedricziel/seer-app/issues/120), R02, MC01, MC02.
- [Copy Quick Connect codes on native macOS](https://github.com/cedricziel/seer-app/issues/121), MC03.
- [Fix welcome branding and adaptive platform layout](https://github.com/cedricziel/seer-app/issues/122), R01, IP01, TV01.
- [Keep series and seasons out of the TV library root](https://github.com/cedricziel/seer-app/issues/123), IP02.
- [Keep media detail actions readable across window sizes](https://github.com/cedricziel/seer-app/issues/124), R06, IP05, MC06, IP04.
- [Diagnose authenticated HLS failures and align codec capabilities](https://github.com/cedricziel/seer-app/issues/125), IP06, MC05.
- [Present actionable playback errors without overlapping controls](https://github.com/cedricziel/seer-app/issues/126), IP06, IP07, MC05.
- [Label ratings and download storage controls accessibly](https://github.com/cedricziel/seer-app/issues/127), R07, R08.
- [Clarify empty downloads and optional service setup](https://github.com/cedricziel/seer-app/issues/128), R03, R04, R05.
- [Verify colon entry with the tvOS server URL keyboard](https://github.com/cedricziel/seer-app/issues/129), TV onboarding blocker.
