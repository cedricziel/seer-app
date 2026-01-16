import Foundation

/// Device profile for Jellyfin playback capability negotiation
public struct DeviceProfile: Codable, Sendable {
    public let name: String?
    public let maxStreamingBitrate: Int?
    public let maxStaticBitrate: Int?
    public let musicStreamingTranscodingBitrate: Int?
    public let directPlayProfiles: [DirectPlayProfile]
    public let transcodingProfiles: [TranscodingProfile]
    public let containerProfiles: [ContainerProfile]
    public let codecProfiles: [CodecProfile]
    public let subtitleProfiles: [SubtitleProfile]

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case maxStreamingBitrate = "MaxStreamingBitrate"
        case maxStaticBitrate = "MaxStaticBitrate"
        case musicStreamingTranscodingBitrate = "MusicStreamingTranscodingBitrate"
        case directPlayProfiles = "DirectPlayProfiles"
        case transcodingProfiles = "TranscodingProfiles"
        case containerProfiles = "ContainerProfiles"
        case codecProfiles = "CodecProfiles"
        case subtitleProfiles = "SubtitleProfiles"
    }

    public init(
        name: String? = nil,
        maxStreamingBitrate: Int? = nil,
        maxStaticBitrate: Int? = nil,
        musicStreamingTranscodingBitrate: Int? = nil,
        directPlayProfiles: [DirectPlayProfile] = [],
        transcodingProfiles: [TranscodingProfile] = [],
        containerProfiles: [ContainerProfile] = [],
        codecProfiles: [CodecProfile] = [],
        subtitleProfiles: [SubtitleProfile] = []
    ) {
        self.name = name
        self.maxStreamingBitrate = maxStreamingBitrate
        self.maxStaticBitrate = maxStaticBitrate
        self.musicStreamingTranscodingBitrate = musicStreamingTranscodingBitrate
        self.directPlayProfiles = directPlayProfiles
        self.transcodingProfiles = transcodingProfiles
        self.containerProfiles = containerProfiles
        self.codecProfiles = codecProfiles
        self.subtitleProfiles = subtitleProfiles
    }
}

// MARK: - Direct Play Profile

public struct DirectPlayProfile: Codable, Sendable {
    public let container: String?
    public let audioCodec: String?
    public let videoCodec: String?
    public let type: MediaType

    public enum MediaType: String, Codable, Sendable {
        case video = "Video"
        case audio = "Audio"
        case photo = "Photo"
    }

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case audioCodec = "AudioCodec"
        case videoCodec = "VideoCodec"
        case type = "Type"
    }

    public init(
        container: String? = nil,
        audioCodec: String? = nil,
        videoCodec: String? = nil,
        type: MediaType
    ) {
        self.container = container
        self.audioCodec = audioCodec
        self.videoCodec = videoCodec
        self.type = type
    }
}

// MARK: - Transcoding Profile

public struct TranscodingProfile: Codable, Sendable {
    public let container: String?
    public let type: DirectPlayProfile.MediaType
    public let audioCodec: String?
    public let videoCodec: String?
    public let context: TranscodingContext
    public let `protocol`: String?
    public let estimateContentLength: Bool?
    public let enableMpegtsM2TsMode: Bool?
    public let transcodeSeekInfo: TranscodeSeekInfo?
    public let copyTimestamps: Bool?
    public let enableSubtitlesInManifest: Bool?
    public let minSegments: Int?
    public let segmentLength: Int?
    public let breakOnNonKeyFrames: Bool?

    public enum TranscodingContext: String, Codable, Sendable {
        case streaming = "Streaming"
        case `static` = "Static"
    }

    public enum TranscodeSeekInfo: String, Codable, Sendable {
        case auto = "Auto"
        case bytes = "Bytes"
    }

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case type = "Type"
        case audioCodec = "AudioCodec"
        case videoCodec = "VideoCodec"
        case context = "Context"
        case `protocol` = "Protocol"
        case estimateContentLength = "EstimateContentLength"
        case enableMpegtsM2TsMode = "EnableMpegtsM2TsMode"
        case transcodeSeekInfo = "TranscodeSeekInfo"
        case copyTimestamps = "CopyTimestamps"
        case enableSubtitlesInManifest = "EnableSubtitlesInManifest"
        case minSegments = "MinSegments"
        case segmentLength = "SegmentLength"
        case breakOnNonKeyFrames = "BreakOnNonKeyFrames"
    }

    public init(
        container: String? = nil,
        type: DirectPlayProfile.MediaType,
        audioCodec: String? = nil,
        videoCodec: String? = nil,
        context: TranscodingContext = .streaming,
        protocol protocolValue: String? = nil,
        estimateContentLength: Bool? = nil,
        enableMpegtsM2TsMode: Bool? = nil,
        transcodeSeekInfo: TranscodeSeekInfo? = nil,
        copyTimestamps: Bool? = nil,
        enableSubtitlesInManifest: Bool? = nil,
        minSegments: Int? = nil,
        segmentLength: Int? = nil,
        breakOnNonKeyFrames: Bool? = nil
    ) {
        self.container = container
        self.type = type
        self.audioCodec = audioCodec
        self.videoCodec = videoCodec
        self.context = context
        self.protocol = protocolValue
        self.estimateContentLength = estimateContentLength
        self.enableMpegtsM2TsMode = enableMpegtsM2TsMode
        self.transcodeSeekInfo = transcodeSeekInfo
        self.copyTimestamps = copyTimestamps
        self.enableSubtitlesInManifest = enableSubtitlesInManifest
        self.minSegments = minSegments
        self.segmentLength = segmentLength
        self.breakOnNonKeyFrames = breakOnNonKeyFrames
    }
}

// MARK: - Container Profile

public struct ContainerProfile: Codable, Sendable {
    public let type: DirectPlayProfile.MediaType
    public let container: String?

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case container = "Container"
    }

    public init(type: DirectPlayProfile.MediaType, container: String? = nil) {
        self.type = type
        self.container = container
    }
}

// MARK: - Codec Profile

public struct CodecProfile: Codable, Sendable {
    public let type: CodecType
    public let codec: String?
    public let conditions: [ProfileCondition]

    public enum CodecType: String, Codable, Sendable {
        case video = "Video"
        case videoAudio = "VideoAudio"
        case audio = "Audio"
    }

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case codec = "Codec"
        case conditions = "Conditions"
    }

    public init(type: CodecType, codec: String? = nil, conditions: [ProfileCondition] = []) {
        self.type = type
        self.codec = codec
        self.conditions = conditions
    }
}

// MARK: - Profile Condition

public struct ProfileCondition: Codable, Sendable {
    public let condition: ConditionType
    public let property: ProfileProperty
    public let value: String?
    public let isRequired: Bool?

    public enum ConditionType: String, Codable, Sendable {
        case equals = "Equals"
        case notEquals = "NotEquals"
        case lessThanEqual = "LessThanEqual"
        case greaterThanEqual = "GreaterThanEqual"
        case equalsAny = "EqualsAny"
    }

    public enum ProfileProperty: String, Codable, Sendable {
        case audioBitrate = "AudioBitrate"
        case audioChannels = "AudioChannels"
        case audioProfile = "AudioProfile"
        case audioSampleRate = "AudioSampleRate"
        case has64BitOffsets = "Has64BitOffsets"
        case height = "Height"
        case interlacedVideoType = "InterlacedVideoType"
        case isAnamorphic = "IsAnamorphic"
        case isAvc = "IsAvc"
        case isInterlaced = "IsInterlaced"
        case isSecondaryAudio = "IsSecondaryAudio"
        case numAudioStreams = "NumAudioStreams"
        case numVideoStreams = "NumVideoStreams"
        case packetLength = "PacketLength"
        case refFrames = "RefFrames"
        case videoBitDepth = "VideoBitDepth"
        case videoBitrate = "VideoBitrate"
        case videoCodecTag = "VideoCodecTag"
        case videoFramerate = "VideoFramerate"
        case videoLevel = "VideoLevel"
        case videoProfile = "VideoProfile"
        case videoTimestamp = "VideoTimestamp"
        case width = "Width"
    }

    enum CodingKeys: String, CodingKey {
        case condition = "Condition"
        case property = "Property"
        case value = "Value"
        case isRequired = "IsRequired"
    }

    public init(
        condition: ConditionType,
        property: ProfileProperty,
        value: String? = nil,
        isRequired: Bool? = nil
    ) {
        self.condition = condition
        self.property = property
        self.value = value
        self.isRequired = isRequired
    }
}

// MARK: - Subtitle Profile

public struct SubtitleProfile: Codable, Sendable {
    public let format: String?
    public let method: SubtitleMethod

    public enum SubtitleMethod: String, Codable, Sendable {
        case encode = "Encode"
        case embed = "Embed"
        case external = "External"
        case hls = "Hls"
        case drop = "Drop"
    }

    enum CodingKeys: String, CodingKey {
        case format = "Format"
        case method = "Method"
    }

    public init(format: String? = nil, method: SubtitleMethod) {
        self.format = format
        self.method = method
    }
}
