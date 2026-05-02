@testable import PlaybackClient
import XCTest

final class DeviceProfileBuilderTests: XCTestCase {
    // MARK: - Top-level Profile

    func testBuildAppleDeviceProfile_hasCorrectName() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        XCTAssertEqual(profile.name, "Seer iOS")
    }

    func testBuildAppleDeviceProfile_hasReasonableBitrates() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        XCTAssertEqual(profile.maxStreamingBitrate, 120_000_000)
        XCTAssertEqual(profile.maxStaticBitrate, 100_000_000)
        XCTAssertEqual(profile.musicStreamingTranscodingBitrate, 384_000)
    }

    // MARK: - Direct Play Profiles

    func testDirectPlayProfiles_includesMP4() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let mp4Profile = profile.directPlayProfiles.first {
            $0.container?.contains("mp4") == true
        }
        XCTAssertNotNil(mp4Profile)
        XCTAssertEqual(mp4Profile?.type, .video)
        XCTAssertTrue(mp4Profile?.videoCodec?.contains("h264") == true)
        XCTAssertTrue(mp4Profile?.videoCodec?.contains("hevc") == true)
        XCTAssertTrue(mp4Profile?.audioCodec?.contains("aac") == true)
    }

    func testDirectPlayProfiles_includesMOV() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let movProfile = profile.directPlayProfiles.first {
            $0.container == "mov"
        }
        XCTAssertNotNil(movProfile)
        XCTAssertEqual(movProfile?.type, .video)
    }

    func testDirectPlayProfiles_includesMKV() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let mkvProfile = profile.directPlayProfiles.first {
            $0.container == "mkv"
        }
        XCTAssertNotNil(mkvProfile)
        XCTAssertEqual(mkvProfile?.type, .video)
    }

    func testDirectPlayProfiles_includesAudioOnlyProfile() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let audioProfile = profile.directPlayProfiles.first { $0.type == .audio }
        XCTAssertNotNil(audioProfile)
        XCTAssertNil(audioProfile?.videoCodec, "Audio profile should have no video codec")
    }

    // MARK: - Transcoding Profiles

    func testTranscodingProfiles_includesHLSWithH264() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let hlsH264 = profile.transcodingProfiles.first { transcoding in
            transcoding.protocol == "hls" && transcoding.videoCodec == "h264"
        }
        XCTAssertNotNil(hlsH264)
        XCTAssertEqual(hlsH264?.container, "ts")
        XCTAssertEqual(hlsH264?.type, .video)
        XCTAssertEqual(hlsH264?.context, .streaming)
    }

    func testTranscodingProfiles_includesHLSWithHEVC() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let hlsHEVC = profile.transcodingProfiles.first { transcoding in
            transcoding.protocol == "hls" && transcoding.videoCodec == "hevc"
        }
        XCTAssertNotNil(hlsHEVC)
        XCTAssertEqual(hlsHEVC?.container, "ts")
    }

    func testTranscodingProfiles_includesAudioOnly() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let audio = profile.transcodingProfiles.first { $0.type == .audio }
        XCTAssertNotNil(audio)
    }

    // MARK: - Codec Profiles

    func testCodecProfiles_includesH264Constraints() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let h264 = profile.codecProfiles.first { $0.codec == "h264" }
        XCTAssertNotNil(h264)
        XCTAssertEqual(h264?.type, .video)

        // 4K width and height limits
        let widthLimit = h264?.conditions.first { $0.property == .width }
        XCTAssertEqual(widthLimit?.value, "3840")
        let heightLimit = h264?.conditions.first { $0.property == .height }
        XCTAssertEqual(heightLimit?.value, "2160")
    }

    func testCodecProfiles_includesHEVCConstraints() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let hevcProfiles = profile.codecProfiles.filter { $0.codec == "hevc" }
        XCTAssertGreaterThanOrEqual(hevcProfiles.count, 1)
    }

    // MARK: - Subtitle Profiles

    func testSubtitleProfiles_externalForVTTAndSRT() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()

        let vtt = profile.subtitleProfiles.first { $0.format == "vtt" }
        XCTAssertEqual(vtt?.method, .external)

        let srt = profile.subtitleProfiles.first { $0.format == "srt" }
        XCTAssertEqual(srt?.method, .external)
    }

    func testSubtitleProfiles_burnsBitmapFormats() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        for format in ["pgs", "pgssub", "sup", "dvdsub", "dvbsub"] {
            let sub = profile.subtitleProfiles.first { $0.format == format }
            XCTAssertEqual(sub?.method, .encode, "\(format) should be encoded (burned in)")
        }
    }

    func testSubtitleProfiles_burnsAssAndSsa() {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let ass = profile.subtitleProfiles.first { $0.format == "ass" }
        let ssa = profile.subtitleProfiles.first { $0.format == "ssa" }
        XCTAssertEqual(ass?.method, .encode)
        XCTAssertEqual(ssa?.method, .encode)
    }

    // MARK: - Encoding

    func testProfile_encodesToValidJSON() throws {
        let profile = DeviceProfileBuilder.buildAppleDeviceProfile()
        let data = try JSONEncoder().encode(profile)
        XCTAssertGreaterThan(data.count, 0)

        // Verify Jellyfin's expected key casing
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["Name"])
        XCTAssertNotNil(json["DirectPlayProfiles"])
        XCTAssertNotNil(json["TranscodingProfiles"])
    }
}
