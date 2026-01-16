import AVKit
import Combine
import JellyfinClient

/// Manages Picture-in-Picture playback state across view transitions.
/// This singleton coordinates between PiP state and view presentation,
/// allowing the player to survive view dismissal during PiP mode.
@MainActor
@Observable
public final class PiPPlaybackManager {
    public static let shared = PiPPlaybackManager()

    /// The player being used in PiP mode (nil when not in PiP)
    public private(set) var pipPlayer: AVPlayer?

    /// Item currently playing in PiP
    public private(set) var pipItem: MediaItem?

    /// Whether PiP is currently active
    public private(set) var isPiPActive: Bool = false

    /// Request to restore player UI (set by delegate, observed by presenting views)
    public var shouldRestorePlayer: Bool = false

    /// Whether we're in the process of restoring UI (prevents clearing player on PiP stop)
    public private(set) var isRestoring: Bool = false

    private init() {}

    /// Call when PiP starts - takes ownership of player
    public func pipDidStart(player: AVPlayer, item: MediaItem) {
        pipPlayer = player
        pipItem = item
        isPiPActive = true
        isRestoring = false
    }

    /// Call when PiP stops normally (not during restoration)
    public func pipDidStop() {
        // Don't clear the player if we're restoring - the new view needs it
        guard !isRestoring else {
            isPiPActive = false
            return
        }

        pipPlayer = nil
        pipItem = nil
        isPiPActive = false
        shouldRestorePlayer = false
    }

    /// Call when user wants to restore UI from PiP
    public func requestRestoreUI() {
        isRestoring = true
        shouldRestorePlayer = true
    }

    /// Clear restoration request after handling and finalize restoration
    public func clearRestoreRequest() {
        shouldRestorePlayer = false
    }

    /// Called after the restored view has taken over the player
    public func finishRestoration() {
        isRestoring = false
        isPiPActive = false
        // Keep pipPlayer and pipItem until the view explicitly stops
    }

    /// Called when playback is fully stopped (view dismissed normally, not PiP)
    public func clearPlayer() {
        pipPlayer = nil
        pipItem = nil
        isPiPActive = false
        isRestoring = false
        shouldRestorePlayer = false
    }
}
