import AVFoundation
import AVKit
import Combine
import DownloadClient
import JellyfinClient
import PlaybackClient
import SeerCore
import SwiftUI

/// ViewModel managing video playback state and AVPlayer
@MainActor
@Observable
public final class VideoPlayerViewModel { // swiftlint:disable:this type_body_length
    // MARK: - Public Properties

    /// The AVPlayer instance
    private(set) var player: AVPlayer?

    /// Whether the player is currently playing
    private(set) var isPlaying: Bool = false

    /// Whether the player is buffering
    private(set) var isBuffering: Bool = true

    /// Current playback position in seconds
    private(set) var currentTime: Double = 0

    /// Total duration in seconds
    private(set) var duration: Double = 0

    /// Whether controls should be visible
    var showControls: Bool = true

    /// Current error message
    private(set) var errorMessage: String?

    /// Whether playback is ready
    private(set) var isReady: Bool = false

    /// Available audio tracks
    private(set) var audioTracks: [MediaStream] = []

    /// Available subtitle tracks
    private(set) var subtitleTracks: [MediaStream] = []

    /// Currently selected audio track index
    private(set) var selectedAudioIndex: Int?

    /// Currently selected subtitle track index (-1 for none)
    private(set) var selectedSubtitleIndex: Int?

    // MARK: - Private Properties

    private let item: MediaItem
    private let appState: AppState
    private var playbackService: PlaybackService?
    private var streamInfo: StreamInfo?
    private var playbackState: PlaybackState?
    private var isPlayingOffline: Bool = false
    private var downloadManager: DownloadManager?

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var progressReportTask: Task<Void, Never>?
    private var controlsHideTask: Task<Void, Never>?

    /// Whether playback has been started (for reporting)
    private var hasReportedStart: Bool = false

    // MARK: - Initialization

    public init(
        item: MediaItem,
        appState: AppState,
        startPositionTicks _: Int64 = 0,
        existingPlayer: AVPlayer? = nil,
        downloadManager: DownloadManager? = nil
    ) {
        self.item = item
        self.appState = appState
        self.downloadManager = downloadManager

        // If we have an existing player (restoration from PiP), use it
        if let existingPlayer {
            player = existingPlayer
            isReady = true
            isBuffering = false
            hasReportedStart = true
            setupAudioSession()
            observePlayer(existingPlayer)
            if let currentItem = existingPlayer.currentItem {
                let dur = currentItem.duration.seconds
                if dur.isFinite { duration = dur }
                let time = existingPlayer.currentTime().seconds
                if time.isFinite { currentTime = time }
            }
        }

        // Initialize playback service if we have credentials
        if let serverURL = appState.jellyfinServerURL,
           let accessToken = appState.jellyfinAccessToken,
           let userID = appState.jellyfinUserID,
           let deviceID = appState.jellyfinDeviceID {
            playbackService = PlaybackService(
                serverURL: serverURL,
                accessToken: accessToken,
                userID: userID,
                deviceID: deviceID
            )
        }
    }

    // Note: Cleanup is handled by the stop() method which should be called
    // from the view's onDisappear. We cannot access MainActor-isolated properties
    // from deinit in Swift 6.

    // MARK: - Public Methods

    /// Load the media and prepare for playback
    func loadMedia(startPositionTicks: Int64 = 0) async {
        // Set up audio session for background playback and PiP
        setupAudioSession()

        isBuffering = true
        errorMessage = nil
        print("[VideoPlayer] Loading media for item: \(item.id)")

        // Check for local downloaded file first
        if let localURL = await getLocalFileURL() {
            print("[VideoPlayer] Found local download, playing offline")
            await loadFromLocalFile(url: localURL, startPositionTicks: startPositionTicks)
            return
        }

        // Fall back to streaming
        guard let service = playbackService else {
            errorMessage = "Not authenticated. Please check your server connection."
            isBuffering = false
            print("[VideoPlayer] Error: PlaybackService is nil - credentials missing")
            print("[VideoPlayer] serverURL: \(appState.jellyfinServerURL?.absoluteString ?? "nil")")
            print("[VideoPlayer] hasToken: \(appState.jellyfinAccessToken != nil)")
            print("[VideoPlayer] userID: \(appState.jellyfinUserID ?? "nil")")
            print("[VideoPlayer] deviceID: \(appState.jellyfinDeviceID ?? "nil")")
            return
        }

        do {
            // Get stream info from server
            let info = try await service.getStreamInfo(
                itemId: item.id,
                startPositionTicks: startPositionTicks
            )
            streamInfo = info

            // Store track information
            audioTracks = info.audioStreams
            subtitleTracks = info.subtitleStreams
            selectedAudioIndex = info.selectedAudioIndex
            selectedSubtitleIndex = info.selectedSubtitleIndex

            // Set duration
            if let dur = info.durationSeconds {
                duration = dur
            }

            // Create player with stream URL
            let playerItem = AVPlayerItem(url: info.url)

            // Add headers if needed for non-HLS streams
            if info.type != .hls {
                let asset = playerItem.asset
                if let urlAsset = asset as? AVURLAsset {
                    // Headers are automatically included via the URL for authenticated requests
                    _ = urlAsset
                }
            }

            let newPlayer = AVPlayer(playerItem: playerItem)
            player = newPlayer

            // Observe player status
            observePlayer(newPlayer)

            // Seek to start position if provided
            if startPositionTicks > 0 {
                let startSeconds = Double(startPositionTicks) / 10_000_000.0
                await newPlayer.seek(
                    to: CMTime(seconds: startSeconds, preferredTimescale: 1000),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                )
            }

            // Initialize playback state
            playbackState = PlaybackState(
                itemId: item.id,
                mediaSourceId: info.mediaSourceId,
                playSessionId: info.playSessionId,
                positionTicks: startPositionTicks,
                playMethod: info.type == .hls ? .transcode : .directPlay
            )

            isReady = true
            print("[VideoPlayer] Ready to play. URL: \(info.url.absoluteString)")
            // Temporarily disabled to debug black screen issue
            // updateNowPlayingInfo(player: newPlayer)

        } catch {
            print("[VideoPlayer] Error loading media: \(error)")
            errorMessage = error.localizedDescription
            isBuffering = false
        }
    }

    /// Check for local downloaded file
    private func getLocalFileURL() async -> URL? {
        guard let manager = downloadManager,
              let serverURL = appState.jellyfinServerURL
        else { return nil }

        let serverID = serverURL.host ?? "default"
        return await manager.localFileURL(forItemID: item.id, serverID: serverID)
    }

    /// Load media from local file
    private func loadFromLocalFile(url: URL, startPositionTicks: Int64) async {
        isPlayingOffline = true

        // Create player from local file
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        player = newPlayer

        // Observe player status
        observePlayer(newPlayer)

        // Get duration from file
        let asset = AVAsset(url: url)
        do {
            let durationValue = try await asset.load(.duration)
            if durationValue.seconds.isFinite {
                duration = durationValue.seconds
            }
        } catch {
            print("[VideoPlayer] Could not load duration from local file: \(error)")
        }

        // Seek to start position if provided
        if startPositionTicks > 0 {
            let startSeconds = Double(startPositionTicks) / 10_000_000.0
            await newPlayer.seek(
                to: CMTime(seconds: startSeconds, preferredTimescale: 1000),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }

        // Initialize playback state for offline
        playbackState = PlaybackState(
            itemId: item.id,
            mediaSourceId: item.id,
            playSessionId: nil,
            positionTicks: startPositionTicks,
            playMethod: .directPlay
        )

        isReady = true
        print("[VideoPlayer] Ready to play offline from: \(url.path)")
    }

    /// Start playback
    func play() {
        player?.play()
        isPlaying = true

        if !hasReportedStart {
            reportPlaybackStart()
            hasReportedStart = true
        }

        startProgressReporting()
        scheduleControlsHide()
    }

    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressReporting()
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Seek to a specific time in seconds
    func seek(to seconds: Double) async {
        guard let player else { return }

        let time = CMTime(seconds: seconds, preferredTimescale: 1000)
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds

        // Update playback state and report immediately
        if var state = playbackState {
            state = state.withPosition(ticks: PlaybackState.positionTicks(from: seconds))
            playbackState = state
            reportProgress()
        }
    }

    /// Skip forward by seconds
    func skipForward(seconds: Double = 10) async {
        let newTime = min(currentTime + seconds, duration)
        await seek(to: newTime)
    }

    /// Skip backward by seconds
    func skipBackward(seconds: Double = 10) async {
        let newTime = max(currentTime - seconds, 0)
        await seek(to: newTime)
    }

    /// Select an audio track
    func selectAudioTrack(index: Int) {
        selectedAudioIndex = index
        // Audio track switching would require reloading the stream with different parameters
        // For MVP, we note the selection but don't reload
    }

    /// Select a subtitle track (-1 for none)
    func selectSubtitleTrack(index: Int) {
        selectedSubtitleIndex = index
        // Similar to audio - for MVP we note selection
    }

    /// Toggle controls visibility
    func toggleControls() {
        showControls.toggle()
        if showControls {
            scheduleControlsHide()
        }
    }

    /// Called when user taps on the video area
    func handleTap() {
        showControls = true
        scheduleControlsHide()
    }

    /// Stop playback and clean up
    func stop() {
        reportPlaybackStopped()
        stopProgressReporting()
        controlsHideTask?.cancel()

        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        player?.pause()
        player = nil
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .moviePlayback
                )
                try AVAudioSession.sharedInstance().setActive(true)
                print("[VideoPlayer] Audio session configured for background playback")
            } catch {
                print("[VideoPlayer] Failed to set up audio session: \(error)")
            }
        #endif
    }

    /// Updates Now Playing info for lock screen / control center
    private func updateNowPlayingInfo(player: AVPlayer) {
        let imageURL = appState.jellyfinServerURL?.appendingPathComponent("Items/\(item.id)/Images/Primary")
        PiPPlaybackManager.shared.updateNowPlayingInfo(
            for: item,
            player: player,
            imageURL: imageURL
        )
    }

    private func observePlayer(_ player: AVPlayer) {
        // Observe time changes
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }

        // Observe playback status via KVO using Combine
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleTimeControlStatus(status)
            }
            .store(in: &cancellables)

        // Observe current item status
        player.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleItemStatus(status)
            }
            .store(in: &cancellables)
    }

    private func handleTimeUpdate(_ time: CMTime) {
        let seconds = time.seconds
        if seconds.isFinite {
            currentTime = seconds
            playbackState = playbackState?.withPosition(
                ticks: PlaybackState.positionTicks(from: seconds)
            )
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing: isPlaying = true; isBuffering = false
        case .paused: isPlaying = false
        case .waitingToPlayAtSpecifiedRate: isBuffering = true
        @unknown default: break
        }
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            isBuffering = false
            if let dur = player?.currentItem?.duration.seconds, dur.isFinite { duration = dur }
        case .failed:
            errorMessage = player?.currentItem?.error?.localizedDescription ?? "Playback failed"
            isBuffering = false
        case .unknown: break
        @unknown default: break
        }
    }

    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled, isPlaying {
                showControls = false
            }
        }
    }

    // MARK: - Progress Reporting

    private func startProgressReporting() {
        stopProgressReporting()
        progressReportTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if !Task.isCancelled {
                    reportProgress()
                }
            }
        }
    }

    private func stopProgressReporting() {
        progressReportTask?.cancel()
        progressReportTask = nil
    }

    private func reportPlaybackStart() {
        guard let state = playbackState, let service = playbackService else { return }
        Task {
            try? await service.reportPlaybackStart(state: state)
        }
    }

    private func reportProgress() {
        guard let state = playbackState, let service = playbackService else { return }
        let updatedState = state.withPaused(!isPlaying)
        Task {
            try? await service.reportPlaybackProgress(state: updatedState)
        }
    }

    private func reportPlaybackStopped() {
        guard let state = playbackState, let service = playbackService else { return }
        Task {
            try? await service.reportPlaybackStopped(state: state)
        }
    }
}

// MARK: - Time Formatting

extension VideoPlayerViewModel {
    /// Format seconds as HH:MM:SS or MM:SS
    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "--:--" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// Progress as a value between 0 and 1
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}
