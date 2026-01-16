import AVKit
import DownloadClient
import JellyfinClient
import PlaybackClient
import SeerCore
import SwiftUI

#if os(iOS)
    /// Main video player view for iOS/iPadOS using AVPlayerViewController for PiP support
    public struct VideoPlayerView: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(DownloadManager.self) private var downloadManager: DownloadManager?

        @State private var viewModel: VideoPlayerViewModel

        private let item: MediaItem
        private let appState: AppState
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
            self.appState = appState
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
                        .accessibilityLabel("Loading video")
                        .accessibilityValue("Please wait")
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
                // Restoration completion is now handled by signalRestorationComplete() in updateUIViewController
                guard existingPlayer == nil else {
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
                    .accessibilityHidden(true)

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
                .accessibilityHint("Double tap to close the player")
            }
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Playback error: \(message)")
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
            let isRestoring = PiPPlaybackManager.shared.isRestoring
            print("[VideoPlayer] updateUIVC - hasPlayer: \(player != nil), isRestoring: \(isRestoring)")
            if controller.player !== player {
                print("[VideoPlayer] updateUIVC - attaching player")
                controller.player = player
                // If we're restoring from PiP, signal that UI is ready now
                if isRestoring, player != nil {
                    print("[VideoPlayer] updateUIVC - signaling restoration complete")
                    PiPPlaybackManager.shared.signalRestorationComplete()
                }
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
                print("[VideoPlayer] willEndFullScreenPresentation called")
                Task { @MainActor in
                    // Don't dismiss if we're in PiP mode or restoring from PiP
                    // The restoration presents the controller, which triggers this delegate
                    let pipManager = PiPPlaybackManager.shared
                    if pipManager.isPiPActive || pipManager.isRestoring {
                        print("[VideoPlayer] Skipping dismiss - PiP active or restoring")
                        return
                    }
                    print("[VideoPlayer] Dismissing player view")
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
                    // Hand off player, controller, AND delegate to PiP manager
                    // CRITICAL: Pass self (Coordinator) to keep it alive after view dismissal!
                    // AVPlayerViewController.delegate is weak, so without storing the delegate
                    // in PiPPlaybackManager, it would be deallocated when the view dismisses.
                    if let player = playerViewController.player {
                        PiPPlaybackManager.shared.pipDidStart(
                            player: player,
                            item: item,
                            controller: playerViewController,
                            delegate: self
                        )
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
                    print("[VideoPlayer] PiP stopped - isRestoring: \(PiPPlaybackManager.shared.isRestoring)")
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
                print("[VideoPlayer] restoreUserInterface delegate called")
                // Use nonisolated(unsafe) to handle Swift 6 concurrency
                // The completion handler must be called on the main thread, which we ensure
                nonisolated(unsafe) let unsafeCompletion = completionHandler

                Task { @MainActor in
                    print("[VideoPlayer] Requesting UI restoration from PiPManager")
                    // Store completion handler - it will be called when the new view is ready
                    PiPPlaybackManager.shared.requestRestoreUI(completion: unsafeCompletion)
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
