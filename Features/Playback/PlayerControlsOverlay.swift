import SwiftUI

/// Custom video player controls overlay
struct PlayerControlsOverlay: View {
    @Bindable var viewModel: VideoPlayerViewModel

    let title: String
    let subtitle: String?
    let onDismiss: () -> Void

    @State private var isDraggingSlider = false
    @State private var showAudioSubtitleSheet = false
    @State private var sliderValue: Double = 0

    var body: some View {
        VStack {
            // Top bar
            topBar

            Spacer()

            // Center play controls
            centerControls

            Spacer()

            // Bottom bar with timeline
            bottomBar
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    .black.opacity(0.7),
                    .clear,
                    .clear,
                    .black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showAudioSubtitleSheet) {
            AudioSubtitleSheet(
                audioTracks: viewModel.audioTracks,
                subtitleTracks: viewModel.subtitleTracks,
                selectedAudioIndex: viewModel.selectedAudioIndex,
                selectedSubtitleIndex: viewModel.selectedSubtitleIndex,
                onSelectAudio: { index in
                    viewModel.selectAudioTrack(index: index)
                },
                onSelectSubtitle: { index in
                    viewModel.selectSubtitleTrack(index: index)
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .buttonStyle(PlayerButtonStyle())
            .accessibilityLabel("Close player")
            .accessibilityHint("Double tap to close the video player")

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)\(subtitle.map { ", \($0)" } ?? "")")

            Spacer()

            // Audio/Subtitle button
            if !viewModel.audioTracks.isEmpty || !viewModel.subtitleTracks.isEmpty {
                Button {
                    showAudioSubtitleSheet = true
                } label: {
                    Image(systemName: "text.bubble")
                        .font(.title2)
                }
                .buttonStyle(PlayerButtonStyle())
                .accessibilityLabel("Audio and subtitles")
                .accessibilityHint("Double tap to choose audio track and subtitles")
            }

            #if os(iOS)
                AirPlayRouteButton()
                    .frame(width: 44, height: 44)
            #endif
        }
        .foregroundStyle(.white)
    }

    // MARK: - Center Controls

    private var centerControls: some View {
        HStack(spacing: 60) {
            // Skip backward
            Button {
                Task {
                    await viewModel.skipBackward(seconds: 10)
                }
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 32))
            }
            .buttonStyle(PlayerButtonStyle())
            .accessibilityLabel("Skip back 10 seconds")

            // Play/Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48))
            }
            .buttonStyle(PlayerButtonStyle())
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
            .accessibilityHint(viewModel.isPlaying ? "Double tap to pause playback" : "Double tap to resume playback")

            // Skip forward
            Button {
                Task {
                    await viewModel.skipForward(seconds: 10)
                }
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 32))
            }
            .buttonStyle(PlayerButtonStyle())
            .accessibilityLabel("Skip forward 10 seconds")
        }
        .foregroundStyle(.white)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Timeline slider
            ProgressSlider(
                value: $sliderValue,
                range: 0 ... max(viewModel.duration, 1),
                isDragging: $isDraggingSlider,
                onEditingChanged: { editing in
                    if !editing {
                        Task {
                            await viewModel.seek(to: sliderValue)
                        }
                    }
                }
            )
            .onChange(of: viewModel.currentTime) { _, newValue in
                if !isDraggingSlider {
                    sliderValue = newValue
                }
            }
            .onAppear {
                sliderValue = viewModel.currentTime
            }
            .accessibilityLabel("Playback position")
            .accessibilityValue(playbackPositionAccessibilityValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    Task { await viewModel.skipForward(seconds: 10) }
                case .decrement:
                    Task { await viewModel.skipBackward(seconds: 10) }
                @unknown default:
                    break
                }
            }

            // Time labels
            HStack {
                Text(viewModel.formatTime(isDraggingSlider ? sliderValue : viewModel.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                    .accessibilityHidden(true)

                Spacer()

                let displayTime = isDraggingSlider ? sliderValue : viewModel.currentTime
                Text("-" + viewModel.formatTime(viewModel.duration - displayTime))
                    .font(.caption)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var playbackPositionAccessibilityValue: String {
        let currentTime = viewModel.formatTime(isDraggingSlider ? sliderValue : viewModel.currentTime)
        let totalTime = viewModel.formatTime(viewModel.duration)
        return "\(currentTime) of \(totalTime)"
    }
}

// MARK: - Progress Slider

struct ProgressSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Binding var isDragging: Bool
    var onEditingChanged: ((Bool) -> Void)?

    @State private var dragValue: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: isDragging ? 8 : 4)

                // Progress fill
                Capsule()
                    .fill(.white)
                    .frame(
                        width: progressWidth(in: geometry.size.width),
                        height: isDragging ? 8 : 4
                    )

                // Thumb (only when dragging)
                if isDragging {
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .offset(x: thumbOffset(in: geometry.size.width))
                }
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let percent = gesture.location.x / geometry.size.width
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(percent)
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onEditingChanged?(true)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 16)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isDragging)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(percent) * totalWidth
    }

    private func thumbOffset(in totalWidth: CGFloat) -> CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(percent) * totalWidth - 8 // Half thumb width
    }
}

// MARK: - Player Button Style

struct PlayerButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black

        // Mock controls for preview
        VStack {
            Text("Preview")
        }
    }
}
