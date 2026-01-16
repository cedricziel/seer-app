import Foundation

/// Builds device profiles for Apple platforms
public enum DeviceProfileBuilder {
    /// Build a device profile for iOS/iPadOS
    public static func buildAppleDeviceProfile() -> DeviceProfile {
        DeviceProfile(
            name: "Seer iOS",
            maxStreamingBitrate: 120_000_000, // 120 Mbps
            maxStaticBitrate: 100_000_000, // 100 Mbps
            musicStreamingTranscodingBitrate: 384_000, // 384 kbps
            directPlayProfiles: directPlayProfiles,
            transcodingProfiles: transcodingProfiles,
            containerProfiles: [],
            codecProfiles: codecProfiles,
            subtitleProfiles: subtitleProfiles
        )
    }

    // MARK: - Direct Play Profiles

    /// Formats that AVPlayer can play directly
    private static var directPlayProfiles: [DirectPlayProfile] {
        [
            // MP4 container with common codecs
            DirectPlayProfile(
                container: "mp4,m4v",
                audioCodec: "aac,ac3,eac3,alac,flac,mp3",
                videoCodec: "h264,hevc,av1",
                type: .video
            ),
            // MOV container
            DirectPlayProfile(
                container: "mov",
                audioCodec: "aac,ac3,eac3,alac,flac,mp3",
                videoCodec: "h264,hevc,av1",
                type: .video
            ),
            // MKV container (AVPlayer has limited MKV support)
            DirectPlayProfile(
                container: "mkv",
                audioCodec: "aac,ac3,eac3,alac,flac,mp3",
                videoCodec: "h264,hevc",
                type: .video
            ),
            // Audio-only
            DirectPlayProfile(
                container: "mp3,aac,m4a,flac,alac,wav",
                audioCodec: "mp3,aac,alac,flac,pcm",
                type: .audio
            )
        ]
    }

    // MARK: - Transcoding Profiles

    /// Fallback transcoding when direct play isn't possible
    private static var transcodingProfiles: [TranscodingProfile] {
        [
            // HLS transcoding with H.264 (most compatible)
            TranscodingProfile(
                container: "ts",
                type: .video,
                audioCodec: "aac,ac3,eac3",
                videoCodec: "h264",
                context: .streaming,
                protocol: "hls",
                estimateContentLength: false,
                enableMpegtsM2TsMode: false,
                transcodeSeekInfo: .auto,
                copyTimestamps: false,
                enableSubtitlesInManifest: true,
                minSegments: 1,
                segmentLength: 6,
                breakOnNonKeyFrames: false
            ),
            // HLS transcoding with HEVC for HDR content
            TranscodingProfile(
                container: "ts",
                type: .video,
                audioCodec: "aac,ac3,eac3",
                videoCodec: "hevc",
                context: .streaming,
                protocol: "hls",
                estimateContentLength: false,
                enableMpegtsM2TsMode: false,
                transcodeSeekInfo: .auto,
                copyTimestamps: false,
                enableSubtitlesInManifest: true,
                minSegments: 1,
                segmentLength: 6,
                breakOnNonKeyFrames: false
            ),
            // Audio transcoding
            TranscodingProfile(
                container: "mp3",
                type: .audio,
                audioCodec: "mp3",
                context: .streaming,
                estimateContentLength: false
            )
        ]
    }

    // MARK: - Codec Profiles

    /// Constraints on codec capabilities
    private static var codecProfiles: [CodecProfile] {
        [
            // H.264 constraints
            CodecProfile(
                type: .video,
                codec: "h264",
                conditions: [
                    ProfileCondition(
                        condition: .lessThanEqual,
                        property: .videoLevel,
                        value: "52", // Level 5.2 (4K)
                        isRequired: false
                    ),
                    ProfileCondition(
                        condition: .lessThanEqual,
                        property: .width,
                        value: "3840",
                        isRequired: false
                    ),
                    ProfileCondition(
                        condition: .lessThanEqual,
                        property: .height,
                        value: "2160",
                        isRequired: false
                    )
                ]
            ),
            // HEVC constraints
            CodecProfile(
                type: .video,
                codec: "hevc",
                conditions: [
                    ProfileCondition(
                        condition: .lessThanEqual,
                        property: .videoLevel,
                        value: "186", // Level 6.2
                        isRequired: false
                    ),
                    ProfileCondition(
                        condition: .lessThanEqual,
                        property: .width,
                        value: "3840",
                        isRequired: false
                    ),
                    ProfileCondition(
                        condition: .lessThanEqual,
                        property: .height,
                        value: "2160",
                        isRequired: false
                    )
                ]
            ),
            // 10-bit video support
            CodecProfile(
                type: .video,
                codec: "hevc",
                conditions: [
                    ProfileCondition(
                        condition: .lessThanEqual,
                        property: .videoBitDepth,
                        value: "10",
                        isRequired: false
                    )
                ]
            )
        ]
    }

    // MARK: - Subtitle Profiles

    /// Supported subtitle formats
    private static var subtitleProfiles: [SubtitleProfile] {
        [
            // VTT - natively supported
            SubtitleProfile(format: "vtt", method: .external),
            // SRT - convert to VTT externally
            SubtitleProfile(format: "srt", method: .external),
            // ASS/SSA - burn into video
            SubtitleProfile(format: "ass", method: .encode),
            SubtitleProfile(format: "ssa", method: .encode),
            // PGS (Blu-ray) - burn into video
            SubtitleProfile(format: "pgs", method: .encode),
            SubtitleProfile(format: "pgssub", method: .encode),
            // SUP - burn into video
            SubtitleProfile(format: "sup", method: .encode),
            // DVD subtitles - burn into video
            SubtitleProfile(format: "dvdsub", method: .encode),
            SubtitleProfile(format: "dvbsub", method: .encode)
        ]
    }
}
