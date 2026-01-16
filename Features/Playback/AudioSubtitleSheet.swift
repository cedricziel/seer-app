import PlaybackClient
import SwiftUI

/// Sheet for selecting audio and subtitle tracks
struct AudioSubtitleSheet: View {
    let audioTracks: [MediaStream]
    let subtitleTracks: [MediaStream]
    let selectedAudioIndex: Int?
    let selectedSubtitleIndex: Int?
    let onSelectAudio: (Int) -> Void
    let onSelectSubtitle: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Audio Section
                if !audioTracks.isEmpty {
                    Section("Audio") {
                        ForEach(audioTracks) { track in
                            AudioTrackRow(
                                track: track,
                                isSelected: selectedAudioIndex == track.index,
                                onSelect: {
                                    onSelectAudio(track.index)
                                }
                            )
                        }
                    }
                }

                // Subtitles Section
                Section("Subtitles") {
                    // Off option
                    Button {
                        onSelectSubtitle(-1)
                    } label: {
                        HStack {
                            Text("Off")
                            Spacer()
                            if selectedSubtitleIndex == nil || selectedSubtitleIndex == -1 {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    ForEach(subtitleTracks) { track in
                        SubtitleTrackRow(
                            track: track,
                            isSelected: selectedSubtitleIndex == track.index,
                            onSelect: {
                                onSelectSubtitle(track.index)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Audio & Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Audio Track Row

private struct AudioTrackRow: View {
    let track: MediaStream
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayTitle ?? track.title ?? "Audio Track \(track.index + 1)")

                    if let details = trackDetails {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var trackDetails: String? {
        var parts: [String] = []

        if let codec = track.codec?.uppercased() {
            parts.append(codec)
        }

        if let channels = track.channels {
            let channelString = switch channels {
            case 1: "Mono"
            case 2: "Stereo"
            case 6: "5.1"
            case 8: "7.1"
            default: "\(channels)ch"
            }
            parts.append(channelString)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

// MARK: - Subtitle Track Row

private struct SubtitleTrackRow: View {
    let track: MediaStream
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayTitle ?? track.title ?? languageName)

                    if let details = trackDetails {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var languageName: String {
        if let lang = track.language {
            return Locale.current.localizedString(forLanguageCode: lang) ?? lang.uppercased()
        }
        return "Subtitle Track \(track.index + 1)"
    }

    private var trackDetails: String? {
        var parts: [String] = []

        if let codec = track.codec?.uppercased() {
            parts.append(codec)
        }

        if track.isExternal == true {
            parts.append("External")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

// MARK: - Preview

#Preview {
    AudioSubtitleSheet(
        audioTracks: [],
        subtitleTracks: [],
        selectedAudioIndex: nil,
        selectedSubtitleIndex: nil,
        onSelectAudio: { _ in },
        onSelectSubtitle: { _ in }
    )
}
