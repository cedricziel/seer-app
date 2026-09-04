import AVFoundation
import AVKit
import Combine
import DownloadClient
import JellyfinClient
import OSLog
import PlaybackClient
import SeerCore
import SwiftUI

private let logger = Logger(subsystem: "com.cedricziel.seer", category: "VideoPlayer")

/// ViewModel managing video playback state and AVPlayer
@MainActor
@Observable
public final class VideoPlayerViewModel {
    // MARK: - Properties

    private(set) var player: AVPlayer?
    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = true
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    var showControls: Bool = true
    private(set) var errorMessage: String?
    private(set) var isReady: Bool = false
    private(set) var audioTracks: [MediaStream] = []
    private(set) var subtitleTracks: [MediaStream] = []
    private(set) var selectedAudioIndex: Int?
    private(set) var selectedSubtitleIndex: Int?

    // MARK: - Private Properties

    private let item: MediaItem
    private let appState: AppState
    private var playbackService: PlaybackService?
    private var streamInfo: StreamInfo?
    private var playbackState: PlaybackState?
    private var isPlayingOffline: Bool = false
    /// Injected by the hosting view from the SwiftUI environment before
    /// loading, so downloaded media plays from disk instead of streaming.
    var downloadManager: DownloadManager?

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var progressReportTask: Task<Void, Never>?
    private var controlsHideTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    /// Whether playback has been started (for reporting)
    private var hasReportedStart: Bool = false

    /// Set once `stop()` has run. A load that was still in flight when the
    /// view went away must not start playback afterwards.
    private var isStopped: Bool = false

    /// Identifies the active load. Bumped by `loadAndPlay()` and `stop()` so
    /// a superseded or cancelled load that resumes after an `await` cannot
    /// install a stale player over the current one.
    private var loadGeneration: Int = 0

    private func isCurrentLoad(_ generation: Int) -> Bool {
        generation == loadGeneration && !isStopped
    }

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
            Self.configureForExternalPlayback(existingPlayer)
            observePlayer(existingPlayer)
            updateNowPlayingInfo(player: existingPlayer)
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

    /// Load the media and auto-play once ready. The load runs in a task owned
    /// by the view model so `stop()` can cancel it if the view is dismissed
    /// before the stream is ready; otherwise playback would start invisibly
    /// in the background.
    func loadAndPlay(startPositionTicks: Int64 = 0) {
        loadTask?.cancel()
        isStopped = false
        loadGeneration += 1
        loadTask = Task { [weak self] in
            guard let self else { return }
            await loadMedia(startPositionTicks: startPositionTicks)
            guard !Task.isCancelled, !isStopped, isReady, errorMessage == nil else { return }
            play()
        }
    }

    /// Load the media and prepare for playback
    func loadMedia(startPositionTicks: Int64 = 0) async {
        let generation = loadGeneration
        setupAudioSession()
        isBuffering = true
        errorMessage = nil
        teardownPlayer()

        // Check for local downloaded file first
        let localURL = await getLocalFileURL()
        guard isCurrentLoad(generation) else { return }
        if let localURL {
            await loadFromLocalFile(url: localURL, startPositionTicks: startPositionTicks, generation: generation)
            return
        }

        // Fall back to streaming
        await loadFromStream(startPositionTicks: startPositionTicks, generation: generation)
    }

    /// Load media from streaming server
    private func loadFromStream(startPositionTicks: Int64, generation: Int) async {
        print("🎬 [VideoPlayer] loadFromStream called for item: \(item.id)")
        guard let service = playbackService else {
            print("🎬 [VideoPlayer] ERROR: No playback service")
            errorMessage = "Not authenticated. Please check your server connection."
            isBuffering = false
            return
        }

        do {
            print("🎬 [VideoPlayer] Getting stream info...")
            let info = try await service.getStreamInfo(
                itemId: item.id,
                startPositionTicks: startPositionTicks
            )
            print("🎬 [VideoPlayer] Got stream info successfully")
            guard isCurrentLoad(generation) else { return }
            streamInfo = info
            audioTracks = info.audioStreams
            subtitleTracks = info.subtitleStreams
            selectedAudioIndex = info.selectedAudioIndex
            selectedSubtitleIndex = info.selectedSubtitleIndex

            if let dur = info.durationSeconds {
                duration = dur
            }

            let playerItem = createPlayerItem(from: info)
            let newPlayer = AVPlayer(playerItem: playerItem)
            player = newPlayer
            Self.configureForExternalPlayback(newPlayer)
            observePlayer(newPlayer)
            updateNowPlayingInfo(player: newPlayer)

            if startPositionTicks > 0 {
                let startSeconds = Double(startPositionTicks) / 10_000_000.0
                await newPlayer.seek(
                    to: CMTime(seconds: startSeconds, preferredTimescale: 1000),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                )
            }

            playbackState = PlaybackState(
                itemId: item.id,
                mediaSourceId: info.mediaSourceId,
                playSessionId: info.playSessionId,
                positionTicks: startPositionTicks,
                playMethod: info.type == .hls ? .transcode : .directPlay
            )

            isReady = true
        } catch is CancellationError {
            // Task was cancelled (e.g., view lifecycle during presentation) - don't show error
            isBuffering = false
            return
        } catch let error as URLError where error.code == .cancelled {
            // URL request was cancelled - treat same as CancellationError
            isBuffering = false
            return
        } catch {
            errorMessage = error.localizedDescription
            isBuffering = false
        }
    }

    /// Check for local downloaded file
    private func getLocalFileURL() async -> URL? {
        guard let manager = downloadManager,
              let serverID = appState.activeServerKey
        else { return nil }

        return await manager.localFileURL(forItemID: item.id, serverID: serverID)
    }

    /// Load media from local file
    private func loadFromLocalFile(url: URL, startPositionTicks: Int64, generation: Int) async {
        isPlayingOffline = true

        // Create player from local file
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        player = newPlayer
        Self.configureForExternalPlayback(newPlayer)

        // Observe player status
        observePlayer(newPlayer)
        updateNowPlayingInfo(player: newPlayer)

        // Get duration from file
        let asset = AVURLAsset(url: url)
        do {
            let durationValue = try await asset.load(.duration)
            if durationValue.seconds.isFinite {
                duration = durationValue.seconds
            }
        } catch {
            // Duration loading failed, will use default
        }
        guard isCurrentLoad(generation) else { return }

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
    }

    /// Start playback
    func play() {
        guard !isStopped else { return }
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

    /// Stop playback and clean up. Safe to call more than once.
    func stop() {
        guard !isStopped else { return }
        isStopped = true
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        reportPlaybackStopped()
        stopProgressReporting()
        controlsHideTask?.cancel()
        teardownPlayer()
    }

    /// Detach observers from the current player and release it. Called before
    /// a new player is created (retry) and from `stop()`, so an old player is
    /// never left running with a live periodic time observer.
    private func teardownPlayer() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        cancellables.removeAll()
        player?.pause()
        player = nil
        isPlaying = false
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                // Audio session setup failed, playback may not work in background
            }
        #endif
    }

    /// Enables AirPlay / external-screen playback on the given player. iOS only;
    /// `AVRoutePickerView` and external-display playback are not available on tvOS.
    private static func configureForExternalPlayback(_ player: AVPlayer) {
        #if os(iOS)
            player.allowsExternalPlayback = true
            player.usesExternalPlaybackWhileExternalScreenIsActive = true
        #endif
    }

    /// Creates an AVPlayerItem with appropriate authentication for the stream type
    private func createPlayerItem(from info: StreamInfo) -> AVPlayerItem {
        // Log stream info for debugging
        let streamTypeStr = switch info.type {
        case .hls: "HLS"
        case .directPlay: "DirectPlay"
        case .directStream: "DirectStream"
        }
        print("🎬 [VideoPlayer] Stream type: \(streamTypeStr)")
        print("🎬 [VideoPlayer] Stream URL: \(StreamURLBuilder.redactedDescription(of: info.url))")

        // All stream types now have auth in URL query params
        return AVPlayerItem(url: info.url)
    }

    /// Updates Now Playing info for lock screen / control center
    private func updateNowPlayingInfo(player: AVPlayer) {
        let imageURL = appState.jellyfinServerURL?.appendingPathComponent("Items/\(item.id)/Images/Primary")
        let playerDuration = player.currentItem?.duration
        let durationSeconds: Double? = if let playerDuration, playerDuration.isNumeric {
            CMTimeGetSeconds(playerDuration)
        } else if duration > 0 {
            duration
        } else {
            nil
        }
        let elapsed = player.currentTime().isNumeric ? CMTimeGetSeconds(player.currentTime()) : 0
        PiPPlaybackManager.shared.updateNowPlayingInfo(
            for: item,
            duration: durationSeconds,
            elapsed: elapsed,
            rate: player.rate,
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
            PiPPlaybackManager.shared.updateNowPlayingPlaybackTime(
                elapsed: seconds,
                rate: player?.rate ?? 0
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
            print("🎬 [VideoPlayer] AVPlayerItem ready to play")
            isBuffering = false
            if let dur = player?.currentItem?.duration.seconds, dur.isFinite { duration = dur }
        case .failed:
            handlePlaybackFailure()
        case .unknown:
            print("🎬 [VideoPlayer] AVPlayerItem status unknown")
        @unknown default: break
        }
    }

    private func handlePlaybackFailure() {
        let playerError = player?.currentItem?.error
        let errorDesc = playerError?.localizedDescription ?? "Playback failed"
        print("🎬 [VideoPlayer] AVPlayerItem FAILED: \(errorDesc)")
        logPlaybackError(playerError)
        let streamTypeStr = streamInfo?.type.debugDescription ?? "Unknown"
        errorMessage = "[\(streamTypeStr)] \(errorDesc)"
        isBuffering = false
    }

    /// Logs only safe error fields. `userInfo` can carry the failing stream
    /// URL, which includes the access token, so it is never printed whole.
    private func logPlaybackError(_ error: Error?) {
        guard let nsError = error as? NSError else { return }
        print("🎬 [VideoPlayer] Error domain: \(nsError.domain), code: \(nsError.code)")
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            print("🎬 [VideoPlayer] Failing URL: \(StreamURLBuilder.redactedDescription(of: failingURL))")
        }
        guard let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError else { return }
        print("🎬 [VideoPlayer] Underlying error: \(underlyingError.domain), code: \(underlyingError.code)")
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
        progressReportTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                reportProgress()
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
