import Foundation

/// Represents a resolved stream URL with all necessary information for playback
public struct StreamInfo: Sendable {
    /// The stream URL to play
    public let url: URL

    /// Type of stream
    public let type: StreamType

    /// The media source this stream is from
    public let mediaSourceId: String

    /// Play session ID for progress reporting
    public let playSessionId: String?

    /// Duration in seconds
    public let durationSeconds: Double?

    /// Available audio streams
    public let audioStreams: [MediaStream]

    /// Available subtitle streams
    public let subtitleStreams: [MediaStream]

    /// Selected audio stream index
    public let selectedAudioIndex: Int?

    /// Selected subtitle stream index (-1 for none)
    public let selectedSubtitleIndex: Int?

    /// Headers to include in requests
    public let headers: [String: String]

    public enum StreamType: Sendable {
        case directPlay
        case directStream
        case hls
    }

    public init(
        url: URL,
        type: StreamType,
        mediaSourceId: String,
        playSessionId: String?,
        durationSeconds: Double?,
        audioStreams: [MediaStream],
        subtitleStreams: [MediaStream],
        selectedAudioIndex: Int?,
        selectedSubtitleIndex: Int?,
        headers: [String: String]
    ) {
        self.url = url
        self.type = type
        self.mediaSourceId = mediaSourceId
        self.playSessionId = playSessionId
        self.durationSeconds = durationSeconds
        self.audioStreams = audioStreams
        self.subtitleStreams = subtitleStreams
        self.selectedAudioIndex = selectedAudioIndex
        self.selectedSubtitleIndex = selectedSubtitleIndex
        self.headers = headers
    }
}

/// Represents the current playback state for progress reporting
public struct PlaybackState: Sendable {
    public let itemId: String
    public let mediaSourceId: String
    public let playSessionId: String?
    public let positionTicks: Int64
    public let isPaused: Bool
    public let isMuted: Bool
    public let volumeLevel: Int
    public let playMethod: PlayMethod

    public enum PlayMethod: String, Sendable {
        case directPlay = "DirectPlay"
        case directStream = "DirectStream"
        case transcode = "Transcode"
    }

    public init(
        itemId: String,
        mediaSourceId: String,
        playSessionId: String?,
        positionTicks: Int64,
        isPaused: Bool = false,
        isMuted: Bool = false,
        volumeLevel: Int = 100,
        playMethod: PlayMethod = .directPlay
    ) {
        self.itemId = itemId
        self.mediaSourceId = mediaSourceId
        self.playSessionId = playSessionId
        self.positionTicks = positionTicks
        self.isPaused = isPaused
        self.isMuted = isMuted
        self.volumeLevel = volumeLevel
        self.playMethod = playMethod
    }

    /// Create a state with updated position
    public func withPosition(ticks: Int64) -> PlaybackState {
        PlaybackState(
            itemId: itemId,
            mediaSourceId: mediaSourceId,
            playSessionId: playSessionId,
            positionTicks: ticks,
            isPaused: isPaused,
            isMuted: isMuted,
            volumeLevel: volumeLevel,
            playMethod: playMethod
        )
    }

    /// Create a state with updated pause status
    public func withPaused(_ paused: Bool) -> PlaybackState {
        PlaybackState(
            itemId: itemId,
            mediaSourceId: mediaSourceId,
            playSessionId: playSessionId,
            positionTicks: positionTicks,
            isPaused: paused,
            isMuted: isMuted,
            volumeLevel: volumeLevel,
            playMethod: playMethod
        )
    }
}

// MARK: - Convenience

public extension PlaybackState {
    /// Position in seconds
    var positionSeconds: Double {
        Double(positionTicks) / 10_000_000.0
    }

    /// Create state from seconds
    static func positionTicks(from seconds: Double) -> Int64 {
        Int64(seconds * 10_000_000.0)
    }
}
