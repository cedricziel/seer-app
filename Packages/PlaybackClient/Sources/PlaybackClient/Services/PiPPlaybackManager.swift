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

    /// Observer for playback time updates
    private var timeObserver: Any?

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

    /// Call when user wants to restore UI from PiP.
    /// This method presents the SAME AVPlayerViewController via UIKit.
    /// - Parameter completion: Completion handler to call when the controller is presented
    public func requestRestoreUI(completion: @escaping (Bool) -> Void) {
        print("[PiPManager] requestRestoreUI - hasController: \(pipController != nil)")
        isRestoring = true
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
        stopTimeObserver()
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

    /// Updates the Now Playing info on the lock screen / control center
    /// - Parameters:
    ///   - item: The media item being played
    ///   - player: The AVPlayer instance
    ///   - imageURL: Optional URL for the artwork image
    public func updateNowPlayingInfo(
        for item: MediaItem,
        player: AVPlayer,
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

        // Duration
        if let duration = player.currentItem?.duration, duration.isNumeric {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(duration)
        } else if let ticks = item.runTimeTicks {
            // Use media item's duration if player duration not available
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(ticks) / 10_000_000.0
        }

        // Current position
        if player.currentTime().isNumeric {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(player.currentTime())
        }

        // Playback rate
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

        // Set initial info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Store artwork URL and fetch it asynchronously
        artworkURL = imageURL
        if let url = imageURL {
            loadArtwork(from: url)
        }

        // Start observing playback time
        startTimeObserver(player: player)
    }

    /// Clears Now Playing info
    private func clearNowPlayingInfo() {
        print("[PiPManager] Clearing Now Playing info")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Loads artwork from URL and updates Now Playing info
    private func loadArtwork(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                #if canImport(UIKit)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                                image
                            }
                            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                            info[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                            print("[PiPManager] Artwork loaded and set")
                        }
                    }
                #endif
            } catch {
                print("[PiPManager] Failed to load artwork: \(error)")
            }
        }
    }

    /// Starts a time observer to keep Now Playing info updated
    private func startTimeObserver(player: AVPlayer) {
        // Stop any existing observer
        stopTimeObserver()

        // Store reference for later cleanup
        timeObserverPlayer = player

        // Update every second
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard time.isNumeric else { return }
            Task { @MainActor in
                guard self != nil else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(time)
                info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    /// The player that the time observer is attached to
    private weak var timeObserverPlayer: AVPlayer?

    /// Stops the time observer
    private func stopTimeObserver() {
        if let observer = timeObserver, let player = timeObserverPlayer {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        timeObserverPlayer = nil
    }

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
