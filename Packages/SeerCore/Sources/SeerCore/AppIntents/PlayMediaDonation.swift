import Foundation
import OSLog
#if canImport(Intents)
    import Intents
#endif

/// Donates `INPlayMediaIntent` interactions to the system after
/// successful playback starts. Lets Siri / system search route
/// "play X again" back to Seer specifically.
///
/// Called from `PlaybackClient` on the playback start success path.
/// Gated on `MediaItem.isResumable` — Live TV streams MUST NOT donate.
public enum PlayMediaDonation {
    private static let logger = Logger(
        subsystem: "com.cedricziel.seer",
        category: "PlayMediaDonation"
    )

    /// Donate a play-media interaction for the given item.
    ///
    /// - Parameters:
    ///   - itemID: stable Jellyfin item id.
    ///   - title: display title.
    ///   - mediaType: "Movie" / "Series" / "Episode" / etc.
    ///   - isResumable: gate — false skips donation entirely.
    public static func donate(
        itemID: String,
        title: String,
        mediaType: String,
        isResumable: Bool
    ) async {
        guard isResumable else {
            logger.debug("Skipping donation for non-resumable item \(itemID, privacy: .public)")
            return
        }

        #if os(iOS) || os(tvOS)
            let mediaItem = INMediaItem(
                identifier: itemID,
                title: title,
                type: inMediaItemType(for: mediaType),
                artwork: nil
            )
            let intent = INPlayMediaIntent(mediaItems: [mediaItem])
            intent.suggestedInvocationPhrase = "Play \(title) on Seer"

            let interaction = INInteraction(intent: intent, response: nil)
            do {
                try await interaction.donate()
                logger.debug("Donated play media for \(itemID, privacy: .public)")
            } catch {
                logger.error("Failed to donate play media: \(String(describing: error))")
            }
        #else
            // Donation API not available on this platform — no-op.
            _ = (itemID, title, mediaType)
        #endif
    }

    #if os(iOS) || os(tvOS)
        private static func inMediaItemType(for mediaType: String) -> INMediaItemType {
            switch mediaType.lowercased() {
            case "movie": .movie
            case "series": .tvShow
            case "episode": .tvShowEpisode
            case "musicvideo": .musicVideo
            case "audio": .song
            default: .movie
            }
        }
    #endif
}
