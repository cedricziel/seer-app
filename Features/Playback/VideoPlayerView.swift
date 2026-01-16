import AVKit
import JellyfinClient
import PlaybackClient
import SeerCore
import SwiftUI

#if os(iOS)
    /// Main video player view for iOS/iPadOS using AVPlayerViewController for PiP support
    public struct VideoPlayerView: View {
        @Environment(\.dismiss) private var dismiss

        @State private var viewModel: VideoPlayerViewModel

        private let item: MediaItem
        private let startPositionTicks: Int64
        private let existingPlayer: AVPlayer?
        private let onPiPStart: (() -> Void)?

        public init(
            item: MediaItem,
            appState: AppState,
            startPositionTicks: Int64 = 0,
            existingPlayer: AVPlayer? = nil,
            onPiPStart: (() -> Void)? = nil
        ) {
            self.item = item
            self.startPositionTicks = startPositionTicks
            self.existingPlayer = existingPlayer
            self.onPiPStart = onPiPStart
            _viewModel = State(wrappedValue: VideoPlayerViewModel(
                item: item,
                appState: appState,
                startPositionTicks: startPositionTicks,
                existingPlayer: existingPlayer
            ))
        }

        public var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                AVPlayerViewControllerRepresentable(
                    player: viewModel.player,
                    item: item,
                    onDismiss: { dismiss() },
                    onPiPStart: { onPiPStart?() },
                    viewModel: viewModel
                )
                .ignoresSafeArea()

                // Loading indicator (shown while loading, before player is ready)
                if viewModel.isBuffering && viewModel.player == nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }

                // Error message
                if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }
            .preferredColorScheme(.dark)
            .persistentSystemOverlays(.hidden)
            .task {
                // Skip loading if we already have a player (restoration from PiP)
                guard existingPlayer == nil else {
                    // Mark restoration as complete
                    PiPPlaybackManager.shared.finishRestoration()
                    if viewModel.isReady && viewModel.errorMessage == nil {
                        viewModel.play()
                    }
                    return
                }
                await viewModel.loadMedia(startPositionTicks: startPositionTicks)
                // Auto-play when ready
                if viewModel.isReady && viewModel.errorMessage == nil {
                    viewModel.play()
                }
            }
            .onDisappear {
                // Only stop if not going to PiP
                if !PiPPlaybackManager.shared.isPiPActive {
                    viewModel.stop()
                    // Clear the manager's player reference
                    PiPPlaybackManager.shared.clearPlayer()
                }
            }
        }

        // MARK: - Subviews

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
    }

    // MARK: - AVPlayerViewController Representable

    struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
        let player: AVPlayer?
        let item: MediaItem
        let onDismiss: () -> Void
        let onPiPStart: () -> Void
        let viewModel: VideoPlayerViewModel

        func makeUIViewController(context: Context) -> AVPlayerViewController {
            let controller = AVPlayerViewController()
            controller.delegate = context.coordinator
            controller.allowsPictureInPicturePlayback = true
            controller.canStartPictureInPictureAutomaticallyFromInline = true
            // Pre-warm the context menu to reduce delay when clicking three dots
            _ = controller.contentOverlayView
            return controller
        }

        func updateUIViewController(_ controller: AVPlayerViewController, context _: Context) {
            if controller.player !== player {
                controller.player = player
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(item: item, onDismiss: onDismiss, onPiPStart: onPiPStart, viewModel: viewModel)
        }

        @MainActor
        class Coordinator: NSObject, AVPlayerViewControllerDelegate {
            let item: MediaItem
            let onDismiss: () -> Void
            let onPiPStart: () -> Void
            let viewModel: VideoPlayerViewModel

            init(
                item: MediaItem,
                onDismiss: @escaping () -> Void,
                onPiPStart: @escaping () -> Void,
                viewModel: VideoPlayerViewModel
            ) {
                self.item = item
                self.onDismiss = onDismiss
                self.onPiPStart = onPiPStart
                self.viewModel = viewModel
            }

            nonisolated func playerViewController(
                _: AVPlayerViewController,
                willEndFullScreenPresentationWithAnimationCoordinator _:
                any UIViewControllerTransitionCoordinator
            ) {
                Task { @MainActor in
                    onDismiss()
                }
            }

            nonisolated func playerViewControllerWillStartPictureInPicture(_: AVPlayerViewController) {
                print("[VideoPlayer] PiP starting")
            }

            nonisolated func playerViewControllerDidStartPictureInPicture(
                _ playerViewController: AVPlayerViewController
            ) {
                print("[VideoPlayer] PiP started")
                Task { @MainActor in
                    // Hand off player to PiP manager
                    if let player = playerViewController.player {
                        PiPPlaybackManager.shared.pipDidStart(player: player, item: item)
                    }
                    // Dismiss the fullScreenCover
                    onPiPStart()
                }
            }

            nonisolated func playerViewControllerWillStopPictureInPicture(_: AVPlayerViewController) {
                print("[VideoPlayer] PiP stopping")
            }

            nonisolated func playerViewControllerDidStopPictureInPicture(_: AVPlayerViewController) {
                print("[VideoPlayer] PiP stopped")
                Task { @MainActor in
                    PiPPlaybackManager.shared.pipDidStop()
                }
            }

            nonisolated func playerViewController(
                _: AVPlayerViewController,
                failedToStartPictureInPictureWithError error: Error
            ) {
                print("[VideoPlayer] PiP failed to start: \(error)")
            }

            nonisolated func playerViewController(
                _: AVPlayerViewController,
                restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
                @escaping (Bool) -> Void
            ) {
                // Use nonisolated(unsafe) to handle Swift 6 concurrency
                // The completion handler must be called on the main thread, which we ensure
                nonisolated(unsafe) let unsafeCompletion = completionHandler

                Task { @MainActor in
                    PiPPlaybackManager.shared.requestRestoreUI()
                    // Give time for UI to restore, then call completion
                    try? await Task.sleep(for: .milliseconds(300))
                    unsafeCompletion(true)
                }
            }
        }
    }
#endif

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
