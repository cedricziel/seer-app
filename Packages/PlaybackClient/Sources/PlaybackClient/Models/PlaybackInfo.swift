import Foundation

// MARK: - PlaybackInfo Response

/// Response from POST /Items/{itemId}/PlaybackInfo
public struct PlaybackInfoResponse: Codable, Sendable {
    public let mediaSources: [MediaSource]
    public let playSessionId: String?

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
        case playSessionId = "PlaySessionId"
    }
}

// MARK: - MediaSource

public struct MediaSource: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let path: String?
    public let container: String?
    public let size: Int64?
    public let bitrate: Int?
    public let supportsDirectPlay: Bool?
    public let supportsDirectStream: Bool?
    public let supportsTranscoding: Bool?
    public let directStreamUrl: String?
    public let transcodingUrl: String?
    public let transcodingSubProtocol: String?
    public let transcodingContainer: String?
    public let mediaStreams: [MediaStream]?
    public let runTimeTicks: Int64?

    public init(
        id: String,
        name: String? = nil,
        path: String? = nil,
        container: String? = nil,
        size: Int64? = nil,
        bitrate: Int? = nil,
        supportsDirectPlay: Bool? = nil,
        supportsDirectStream: Bool? = nil,
        supportsTranscoding: Bool? = nil,
        directStreamUrl: String? = nil,
        transcodingUrl: String? = nil,
        transcodingSubProtocol: String? = nil,
        transcodingContainer: String? = nil,
        mediaStreams: [MediaStream]? = nil,
        runTimeTicks: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.container = container
        self.size = size
        self.bitrate = bitrate
        self.supportsDirectPlay = supportsDirectPlay
        self.supportsDirectStream = supportsDirectStream
        self.supportsTranscoding = supportsTranscoding
        self.directStreamUrl = directStreamUrl
        self.transcodingUrl = transcodingUrl
        self.transcodingSubProtocol = transcodingSubProtocol
        self.transcodingContainer = transcodingContainer
        self.mediaStreams = mediaStreams
        self.runTimeTicks = runTimeTicks
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case path = "Path"
        case container = "Container"
        case size = "Size"
        case bitrate = "Bitrate"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case directStreamUrl = "DirectStreamUrl"
        case transcodingUrl = "TranscodingUrl"
        case transcodingSubProtocol = "TranscodingSubProtocol"
        case transcodingContainer = "TranscodingContainer"
        case mediaStreams = "MediaStreams"
        case runTimeTicks = "RunTimeTicks"
    }
}

// MARK: - MediaStream

public struct MediaStream: Codable, Sendable, Identifiable {
    public var id: Int {
        index
    }

    public let index: Int
    public let type: StreamType
    public let codec: String?
    public let language: String?
    public let displayTitle: String?
    public let title: String?
    public let isDefault: Bool?
    public let isExternal: Bool?
    public let deliveryUrl: String?
    public let width: Int?
    public let height: Int?
    public let bitRate: Int?
    public let channels: Int?
    public let sampleRate: Int?

    public init(
        index: Int,
        type: StreamType,
        codec: String? = nil,
        language: String? = nil,
        displayTitle: String? = nil,
        title: String? = nil,
        isDefault: Bool? = nil,
        isExternal: Bool? = nil,
        deliveryUrl: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        bitRate: Int? = nil,
        channels: Int? = nil,
        sampleRate: Int? = nil
    ) {
        self.index = index
        self.type = type
        self.codec = codec
        self.language = language
        self.displayTitle = displayTitle
        self.title = title
        self.isDefault = isDefault
        self.isExternal = isExternal
        self.deliveryUrl = deliveryUrl
        self.width = width
        self.height = height
        self.bitRate = bitRate
        self.channels = channels
        self.sampleRate = sampleRate
    }

    public enum StreamType: String, Codable, Sendable {
        case video = "Video"
        case audio = "Audio"
        case subtitle = "Subtitle"
        case embeddedImage = "EmbeddedImage"
        case unknown = "Unknown"

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = StreamType(rawValue: rawValue) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case title = "Title"
        case isDefault = "IsDefault"
        case isExternal = "IsExternal"
        case deliveryUrl = "DeliveryUrl"
        case width = "Width"
        case height = "Height"
        case bitRate = "BitRate"
        case channels = "Channels"
        case sampleRate = "SampleRate"
    }
}

// MARK: - Convenience Extensions

public extension MediaSource {
    /// Get all video streams
    var videoStreams: [MediaStream] {
        mediaStreams?.filter { $0.type == .video } ?? []
    }

    /// Get all audio streams
    var audioStreams: [MediaStream] {
        mediaStreams?.filter { $0.type == .audio } ?? []
    }

    /// Get all subtitle streams
    var subtitleStreams: [MediaStream] {
        mediaStreams?.filter { $0.type == .subtitle } ?? []
    }

    /// Default audio stream
    var defaultAudioStream: MediaStream? {
        audioStreams.first { $0.isDefault == true } ?? audioStreams.first
    }

    /// Default subtitle stream (may be nil if none is default)
    var defaultSubtitleStream: MediaStream? {
        subtitleStreams.first { $0.isDefault == true }
    }

    /// Runtime in seconds
    var runtimeSeconds: Double? {
        guard let ticks = runTimeTicks else { return nil }
        return Double(ticks) / 10_000_000.0
    }
}
