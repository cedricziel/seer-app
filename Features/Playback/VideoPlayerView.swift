import AVKit
import JellyfinClient
import PlaybackClient
import SeerCore
import SwiftUI

/// Main video player view for iOS/iPadOS
public struct VideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: VideoPlayerViewModel
    @State private var dragOffset: CGFloat = 0

    private let item: MediaItem
    private let startPositionTicks: Int64
    private let dismissThreshold: CGFloat = 150

    public init(
        item: MediaItem,
        appState: AppState,
        startPositionTicks: Int64 = 0
    ) {
        self.item = item
        self.startPositionTicks = startPositionTicks
        _viewModel = State(wrappedValue: VideoPlayerViewModel(
            item: item,
            appState: appState,
            startPositionTicks: startPositionTicks
        ))
    }

    public var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Video Player
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            // Tap overlay for controls toggle (transparent, above video)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.handleTap()
                }

            // Loading indicator
            if viewModel.isBuffering {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }

            // Error message
            if let error = viewModel.errorMessage {
                errorView(error)
            }

            // Controls overlay
            if viewModel.showControls && viewModel.isReady {
                PlayerControlsOverlay(
                    viewModel: viewModel,
                    title: item.name,
                    subtitle: buildSubtitle(),
                    onDismiss: {
                        closePlayer()
                    }
                )
                .transition(.opacity)
            }

        }
        .offset(y: dragOffset)
        .animation(.interactiveSpring(), value: dragOffset)
        .gesture(dismissDragGesture)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showControls)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .task {
            await viewModel.loadMedia(startPositionTicks: startPositionTicks)
            // Auto-play when ready
            if viewModel.isReady && viewModel.errorMessage == nil {
                viewModel.play()
            }
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    // MARK: - Subviews

    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow dragging down
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold {
                    closePlayer()
                } else {
                    dragOffset = 0
                }
            }
    }

    private func closePlayer() {
        viewModel.stop()
        dismiss()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Playback Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .foregroundStyle(.white)
    }

    // MARK: - Helpers

    private func buildSubtitle() -> String? {
        switch item.type {
        case .episode:
            if let seriesName = item.seriesName {
                var subtitle = seriesName
                if let season = item.parentIndexNumber {
                    subtitle += " - S\(season)"
                }
                if let episode = item.indexNumber {
                    subtitle += "E\(episode)"
                }
                return subtitle
            }
            return nil
        case .movie:
            if let year = item.year {
                return String(year)
            }
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    VideoPlayerView(
        item: MediaItem(
            id: "test",
            name: "Test Movie",
            type: .movie
        ),
        appState: AppState()
    )
}
