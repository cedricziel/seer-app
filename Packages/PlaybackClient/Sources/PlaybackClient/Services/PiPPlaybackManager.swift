import AVKit
import Combine
import JellyfinClient
import MediaPlayer
#if canImport(UIKit)
    import UIKit
#endif

/// Manages Picture-in-Picture playback state across view transitions.
/// This singleton coordinates between PiP state and view presentation,
/// allowing the player to survive view dismissal during PiP mode.
///
/// CRITICAL: The AVPlayerViewController must be the SAME instance that was presented
/// before PiP was triggered. This manager preserves the controller reference to
/// enable proper restoration when exiting PiP.
@MainActor
@Observable
public final class PiPPlaybackManager {
    public static let shared = PiPPlaybackManager()

    /// The player being used in PiP mode (nil when not in PiP)
    public private(set) var pipPlayer: AVPlayer?

    /// Item currently playing in PiP
    public private(set) var pipItem: MediaItem?

    /// The AVPlayerViewController that entered PiP - MUST be preserved for restoration
    public private(set) var pipController: AVPlayerViewController?

    /// Whether PiP is currently active
    public private(set) var isPiPActive: Bool = false

    /// Request to restore player UI (set by delegate, observed by presenting views)
    /// Note: This is kept for backwards compatibility but restoration now uses UIKit presentation
    public var shouldRestorePlayer: Bool = false

    /// Whether we're in the process of restoring UI (prevents clearing player on PiP stop)
    public private(set) var isRestoring: Bool = false

    /// Stores the restore completion handler until presentation completes
    private var restoreCompletionHandler: ((Bool) -> Void)?

    /// The delegate for the PiP controller - kept alive to handle restoration
    /// This MUST be stored because AVPlayerViewController.delegate is weak
    private var pipDelegate: (any AVPlayerViewControllerDelegate)?

    /// Image URL for the current item's artwork (used for Now Playing info)
    private var artworkURL: URL?

    private init() {
        setupLifecycleObservers()
        setupRemoteCommandCenter()
    }

    // MARK: - Lifecycle Observers

    private func setupLifecycleObservers() {
        #if canImport(UIKit)
            // Observe when app becomes active (returns to foreground)
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidBecomeActive()
                }
            }

            // Observe audio session interruptions
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract values before crossing isolation boundary to avoid data race
                let userInfo = notification.userInfo
                let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
                Task { @MainActor in
                    self?.handleAudioSessionInterruption(typeValue: typeValue, optionsValue: optionsValue)
                }
            }
        #endif
    }

    private func handleAppDidBecomeActive() {
        // If PiP is active and player exists, reactivate audio session
        // but do NOT auto-resume playback - respect user's pause state
        guard isPiPActive, pipPlayer != nil else { return }

        print("[PiPManager] App became active with PiP - reactivating audio session")

        // Reactivate audio session to ensure playback CAN continue
        // but don't force it to resume if user paused
        reactivateAudioSession()
    }

    private func handleAudioSessionInterruption(typeValue: UInt?, optionsValue: UInt?) {
        #if canImport(UIKit)
            guard let typeValue,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            switch type {
            case .began:
                print("[PiPManager] Audio session interrupted")
            case .ended:
                print("[PiPManager] Audio session interruption ended")
                // Check if we should resume
                if let optionsValue {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume), isPiPActive {
                        reactivateAudioSession()
                        pipPlayer?.play()
                    }
                }
            @unknown default:
                break
            }
        #endif
    }

    private func reactivateAudioSession() {
        #if canImport(UIKit)
            do {
                try AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .moviePlayback,
                    options: []
                )
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                print("[PiPManager] Audio session reactivated")
            } catch {
                print("[PiPManager] Failed to reactivate audio session: \(error)")
            }
        #endif
    }

    /// Call when PiP starts - takes ownership of player and controller
    /// - Parameters:
    ///   - player: The AVPlayer being used
    ///   - item: The media item being played
    ///   - controller: The AVPlayerViewController - MUST be preserved for restoration
    /// Call when PiP starts - takes ownership of player, controller, AND delegate
    /// - Parameters:
    ///   - player: The AVPlayer being used
    ///   - item: The media item being played
    ///   - controller: The AVPlayerViewController - MUST be preserved for restoration
    ///   - delegate: The AVPlayerViewControllerDelegate - MUST be stored to survive view deallocation
    public func pipDidStart(
        player: AVPlayer,
        item: MediaItem,
        controller: AVPlayerViewController,
        delegate: any AVPlayerViewControllerDelegate
    ) {
        print("[PiPManager] pipDidStart - storing delegate to prevent deallocation")
        pipPlayer = player
        pipItem = item
        pipController = controller
        pipDelegate = delegate // CRITICAL: Keep delegate alive!
        isPiPActive = true
        isRestoring = false
    }

    /// Call when PiP stops normally (not during restoration)
    public func pipDidStop() {
        print("[PiPManager] pipDidStop - isRestoring: \(isRestoring)")
        // Don't clear the player if we're restoring - the controller needs it
        guard !isRestoring else {
            print("[PiPManager] pipDidStop - preserving player for restoration")
            isPiPActive = false
            return
        }

        print("[PiPManager] pipDidStop - clearing player (not restoring)")
        pipPlayer = nil
        pipItem = nil
        pipController = nil
        isPiPActive = false
        shouldRestorePlayer = false
    }

    /// Marks the start of a restoration flow without doing any UIKit presentation.
    /// While `isRestoring` is true, `pipDidStop()` will preserve the player/item/
    /// controller so the caller can hand them off. Pair every call with a matching
    /// `finishRestoration(success:)`.
    func beginRestoration() {
        isRestoring = true
    }

    /// Call when user wants to restore UI from PiP.
    /// This method presents the SAME AVPlayerViewController via UIKit.
    /// - Parameter completion: Completion handler to call when the controller is presented
    public func requestRestoreUI(completion: @escaping (Bool) -> Void) {
        print("[PiPManager] requestRestoreUI - hasController: \(pipController != nil)")
        beginRestoration()
        restoreCompletionHandler = completion

        guard let controller = pipController else {
            print("[PiPManager] ERROR: No controller to restore!")
            completion(false)
            finishRestoration(success: false)
            return
        }

        // Ensure audio session is active before presenting
        reactivateAudioSession()

        // Resume playback if needed
        if let player = pipPlayer, player.timeControlStatus != .playing {
            print("[PiPManager] Resuming player before restoration")
            player.play()
        }

        #if canImport(UIKit)
            presentController(controller, completion: completion)
        #else
            completion(false)
            finishRestoration(success: false)
        #endif
    }

    #if canImport(UIKit)
        /// Presents the preserved AVPlayerViewController via UIKit
        private func presentController(_ controller: AVPlayerViewController, completion: @escaping (Bool) -> Void) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController
            else {
                print("[PiPManager] ERROR: No root view controller found")
                completion(false)
                finishRestoration(success: false)
                return
            }

            // Find the topmost presented view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            print("[PiPManager] Presenting controller from: \(type(of: topVC))")

            // Configure for full screen presentation
            controller.modalPresentationStyle = .fullScreen

            topVC.present(controller, animated: true) { [weak self] in
                print("[PiPManager] Controller presentation completed")
                completion(true)
                self?.finishRestoration(success: true)
            }
        }
    #endif

    /// Finishes the restoration process
    private func finishRestoration(success: Bool) {
        print("[PiPManager] finishRestoration - success: \(success)")
        isRestoring = false
        isPiPActive = false
        shouldRestorePlayer = false
        restoreCompletionHandler = nil
        // Keep pipPlayer, pipItem, and pipController until explicitly cleared
    }

    /// Clear restoration request after handling (for backwards compatibility)
    public func clearRestoreRequest() {
        shouldRestorePlayer = false
    }

    /// Called when new VideoPlayerView is ready and player is attached.
    /// Note: With UIKit presentation, this is now handled in finishRestoration
    public func signalRestorationComplete() {
        print("[PiPManager] signalRestorationComplete - hasCompletion: \(restoreCompletionHandler != nil)")
        restoreCompletionHandler?(true)
        restoreCompletionHandler = nil
        isRestoring = false
        isPiPActive = false
        shouldRestorePlayer = false
        print("[PiPManager] signalRestorationComplete - done, player: \(String(describing: pipPlayer))")
    }

    /// Called when playback is fully stopped (view dismissed normally, not PiP)
    public func clearPlayer() {
        print("[PiPManager] clearPlayer")
        clearNowPlayingInfo()
        pipPlayer = nil
        pipItem = nil
        pipController = nil
        pipDelegate = nil // Release delegate
        artworkURL = nil
        isPiPActive = false
        isRestoring = false
        shouldRestorePlayer = false
        restoreCompletionHandler = nil
    }

    // MARK: - Now Playing Info

    /// Updates the Now Playing info on the lock screen / control center.
    ///
    /// This sets the static metadata (title, artist, duration, artwork) and an
    /// initial elapsed-time / rate snapshot. Live elapsed-time updates are
    /// driven by the caller via ``updateNowPlayingPlaybackTime(elapsed:rate:)``
    /// — we deliberately do NOT register a separate periodic time observer
    /// here. Adding one on top of `VideoPlayerViewModel`'s existing observer
    /// requires capturing the `AVPlayer` into a non-MainActor `@Sendable`
    /// closure, which is unsafe under Swift 6.2 strict isolation and was
    /// crashing Release builds when any media was played.
    ///
    /// - Parameters:
    ///   - item: The media item being played
    ///   - duration: Total duration in seconds, or `nil` if unknown
    ///   - elapsed: Current playback position in seconds
    ///   - rate: Current playback rate (0 = paused, 1 = playing)
    ///   - imageURL: Optional URL for the artwork image
    public func updateNowPlayingInfo(
        for item: MediaItem,
        duration: Double?,
        elapsed: Double,
        rate: Float,
        imageURL: URL?
    ) {
        print("[PiPManager] Updating Now Playing info for: \(item.name)")

        var nowPlayingInfo = [String: Any]()

        // Title
        nowPlayingInfo[MPMediaItemPropertyTitle] = item.name

        // Artist/Album - for episodes, use series name
        if let seriesName = item.seriesName {
            nowPlayingInfo[MPMediaItemPropertyArtist] = seriesName
            // For episodes, show S01E02 format
            if let season = item.parentIndexNumber, let episode = item.indexNumber {
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Season \(season), Episode \(episode)"
            }
        } else if item.type == .movie {
            // For movies, use year as album
            if let year = item.year {
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = String(year)
            }
        }

        // Duration — prefer caller-supplied value, fall back to the item's runtime
        if let duration, duration.isFinite {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        } else if let ticks = item.runTimeTicks {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(ticks) / 10_000_000.0
        }

        if elapsed.isFinite {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Store artwork URL and fetch it asynchronously
        artworkURL = imageURL
        if let url = imageURL {
            loadArtwork(from: url)
        }
    }

    /// Pushes a live elapsed-time / rate update into the Now Playing info.
    /// Designed to be called from the existing playback time observer in the
    /// view-model layer, so the singleton never has to capture the player.
    public func updateNowPlayingPlaybackTime(elapsed: Double, rate: Float) {
        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if elapsed.isFinite {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clears Now Playing info
    private func clearNowPlayingInfo() {
        print("[PiPManager] Clearing Now Playing info")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Loads artwork from URL and updates Now Playing info.
    ///
    /// CRITICAL: `MPMediaItemArtwork`'s `requestHandler` is invoked by
    /// `MPNowPlayingInfoCenter` on its own internal serial queue
    /// whenever the system needs the bitmap (lock screen, control
    /// centre, AirPlay receiver). The handler MUST NOT inherit
    /// `@MainActor` isolation from the surrounding scope — if it
    /// does, Swift 6 strict-concurrency runtime traps with
    /// `_dispatch_assert_queue_fail` when MediaPlayer pulls the
    /// artwork off-main. Build it via the helper below so the
    /// closure is created in a nonisolated context.
    private func loadArtwork(from url: URL) {
        Task.detached {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                #if canImport(UIKit)
                    guard let image = UIImage(data: data) else { return }
                    let artwork = Self.makeArtwork(from: image)
                    await MainActor.run {
                        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        info[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                        print("[PiPManager] Artwork loaded and set")
                    }
                #endif
            } catch {
                print("[PiPManager] Failed to load artwork: \(error)")
            }
        }
    }

    #if canImport(UIKit)
        /// Builds an `MPMediaItemArtwork` whose `requestHandler` closure
        /// is `@Sendable` and nonisolated, so MediaPlayer can call it
        /// from any queue. The static context guarantees the closure
        /// does NOT inherit any actor isolation.
        nonisolated static func makeArtwork(from image: UIImage) -> MPMediaItemArtwork {
            MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in
                image
            }
        }
    #endif

    // MARK: - Remote Command Center

    /// Sets up remote command handlers for play/pause/seek
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pipPlayer?.play()
            }
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pipPlayer?.pause()
            }
            return .success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let player = self?.pipPlayer else { return }
                if player.timeControlStatus == .playing {
                    player.pause()
                } else {
                    player.play()
                }
            }
            return .success
        }

        // Skip forward (15 seconds)
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                guard let player = self?.pipPlayer,
                      let skipEvent = event as? MPSkipIntervalCommandEvent
                else { return }
                let skipTime = CMTime(seconds: skipEvent.interval, preferredTimescale: 1)
                let newTime = CMTimeAdd(player.currentTime(), skipTime)
                player.seek(to: newTime)
            }
            return .success
        }

        // Skip backward (15 seconds)
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                guard let player = self?.pipPlayer,
                      let skipEvent = event as? MPSkipIntervalCommandEvent
                else { return }
                let skipTime = CMTime(seconds: skipEvent.interval, preferredTimescale: 1)
                let newTime = CMTimeSubtract(player.currentTime(), skipTime)
                player.seek(to: newTime)
            }
            return .success
        }

        // Seek command
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            Task { @MainActor in
                guard let player = self?.pipPlayer,
                      let positionEvent = event as? MPChangePlaybackPositionCommandEvent
                else { return }
                let newTime = CMTime(seconds: positionEvent.positionTime, preferredTimescale: 1)
                player.seek(to: newTime)
            }
            return .success
        }
    }
}
