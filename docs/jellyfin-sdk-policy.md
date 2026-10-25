# Jellyfin SDK and server compatibility

Seer targets the current stable Jellyfin server and the current stable Swift SDK.
Older server releases are best-effort compatibility targets. Seer does not add
legacy endpoint fallbacks solely to support an obsolete server branch.
Jellyfin's upstream [security policy](https://github.com/jellyfin/jellyfin/security)
guarantees security patches only for its most recent stable release.

The policy review on October 25, 2026 found server
[12.3](https://github.com/jellyfin/jellyfin/releases/tag/v12.3) and Swift SDK
[3.3.0](https://github.com/jellyfin/jellyfin-sdk-swift/releases/tag/3.3.0) current.
The SDK was generated from the server 12.1 API. These versions record the review;
they do not freeze the support policy to those releases.

## Confirmed legacy gap

The SDK uses `/UserViews`, `/Items/{itemId}`, `/Items/Latest`, `/UserItems/Resume`,
`/UserFavoriteItems/{itemId}`, and `/UserPlayedItems/{itemId}`, with the user ID in
the query where required. Jellyfin 10.8.13 lacks these route forms. Its affected
operations use `/Users/{userId}/...` instead. A direct SDK migration therefore
breaks library loading, item details, latest items, Continue Watching, favorites,
and played-state changes on that release.

Those route forms exist in 10.9.0, 10.10.0, and 10.11.0. This source check establishes
route availability, not complete compatibility with every SDK request or response.
It does not make those older branches supported or tested releases.

The comparison uses the official controllers for
[10.8.13](https://github.com/jellyfin/jellyfin/tree/v10.8.13/Jellyfin.Api/Controllers)
and [10.9.0](https://github.com/jellyfin/jellyfin/tree/v10.9.0/Jellyfin.Api/Controllers).
No 10.8-specific compatibility layer is maintained.

## SDK boundary

Generated SDK requests and its transport handle covered Jellyfin REST operations.
`JellyfinService` remains the app-facing interface. App-owned Codable models remain
the boundary for views, offline caches, and persisted data; replacing them with
SDK DTOs requires a separate persistence and decoding review.

The following behavior remains app-owned:

- AVPlayer playback, codec and device-profile selection, and stream/subtitle URL policy.
- Background download sessions, delegate callbacks, resume data, and file storage.
- Bonjour discovery and LAN/WAN reachability probes. SDK UDP discovery is a different mechanism.
- Quick Connect UI state, adaptive polling, cancellation, and expiry policy.
- Credential storage, server switching, and local logout. Adopting an SDK helper must not add API-key revocation to logout.

SDK request construction must preserve reverse-proxy base paths, stable device
identity, restored tokens, existing timeout policies, pagination, error status and
response bodies, and playback profile/report fields. Tests compare encoded request
bodies where bridging through SDK DTOs could discard fields.

## Verification

The release gate covers authentication and restored credentials, Quick Connect,
library and item requests, search pagination, image URLs, playback negotiation and
reporting, and offline model decoding. iOS and tvOS compilation are checked
separately. Tests use isolated sessions, temporary build paths, and disposable
simulators; they do not use a person's configured server or credentials.

A recorded server route or a passing stubbed transport test is not a live-server
integration result. PRs state which server/runtime combinations were actually
exercised and distinguish existing platform or snapshot failures from regressions.
