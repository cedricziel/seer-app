import AVKit
import DownloadClient
import JellyfinClient
import os
import PlaybackClient
import SeerCore
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "com.seer.app", category: "VideoPlayerView")

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
            .onAppear {
                // Skip loading if we already have a player (restoration from PiP)
                // Restoration completion is now handled by signalRestorationComplete() in updateUIViewController
                guard existingPlayer == nil else {
                    if viewModel.isReady && viewModel.errorMessage == nil {
                        viewModel.play()
                    }
                    return
                }
                // Use explicit Task to avoid SwiftUI's .task cancellation during fullScreenCover presentation
                Task {
                    await viewModel.loadMedia(startPositionTicks: startPositionTicks)
                    // Auto-play when ready
                    if viewModel.isReady && viewModel.errorMessage == nil {
                        viewModel.play()
                    }
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

                HStack(spacing: 16) {
                    Button("Retry") {
                        Task {
                            await viewModel.loadMedia(startPositionTicks: startPositionTicks)
                            if viewModel.isReady && viewModel.errorMessage == nil {
                                viewModel.play()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Double tap to retry loading the video")

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Double tap to close the player")
                }
                .padding(.top)
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

            // Set up double-tap to seek gesture overlay
            setupDoubleTapGestures(on: controller, coordinator: context.coordinator)

            return controller
        }

        private func setupDoubleTapGestures(on controller: AVPlayerViewController, coordinator: Coordinator) {
            guard let overlayView = controller.contentOverlayView else { return }

            // Create left and right tap zones
            let leftTapView = DoubleTapSeekView(isForward: false)
            let rightTapView = DoubleTapSeekView(isForward: true)

            leftTapView.translatesAutoresizingMaskIntoConstraints = false
            rightTapView.translatesAutoresizingMaskIntoConstraints = false

            overlayView.addSubview(leftTapView)
            overlayView.addSubview(rightTapView)

            NSLayoutConstraint.activate([
                // Left half of screen
                leftTapView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
                leftTapView.topAnchor.constraint(equalTo: overlayView.topAnchor),
                leftTapView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),
                leftTapView.widthAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 0.5),
                // Right half of screen
                rightTapView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
                rightTapView.topAnchor.constraint(equalTo: overlayView.topAnchor),
                rightTapView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),
                rightTapView.widthAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 0.5)
            ])

            // Set up double-tap gestures
            let leftDoubleTap = UITapGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.handleLeftDoubleTap(_:))
            )
            leftDoubleTap.numberOfTapsRequired = 2
            leftTapView.addGestureRecognizer(leftDoubleTap)

            let rightDoubleTap = UITapGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.handleRightDoubleTap(_:))
            )
            rightDoubleTap.numberOfTapsRequired = 2
            rightTapView.addGestureRecognizer(rightDoubleTap)

            // Store views in coordinator for feedback animation
            coordinator.leftSeekView = leftTapView
            coordinator.rightSeekView = rightTapView
        }

        func updateUIViewController(_ controller: AVPlayerViewController, context _: Context) {
            let isRestoring = PiPPlaybackManager.shared.isRestoring
            logger.debug("[VideoPlayer] updateUIVC - hasPlayer: \(player != nil), isRestoring: \(isRestoring)")
            if controller.player !== player {
                logger.debug("[VideoPlayer] updateUIVC - attaching player")
                controller.player = player
                // If we're restoring from PiP, signal that UI is ready now
                if isRestoring, player != nil {
                    logger.debug("[VideoPlayer] updateUIVC - signaling restoration complete")
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

            // Double-tap seek views for visual feedback
            weak var leftSeekView: DoubleTapSeekView?
            weak var rightSeekView: DoubleTapSeekView?

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

            // MARK: - Double-Tap Seek Handlers

            @objc func handleLeftDoubleTap(_ gesture: UITapGestureRecognizer) {
                guard gesture.state == .ended else { return }
                leftSeekView?.showFeedback()
                Task {
                    await viewModel.skipBackward(seconds: 10)
                }
            }

            @objc func handleRightDoubleTap(_ gesture: UITapGestureRecognizer) {
                guard gesture.state == .ended else { return }
                rightSeekView?.showFeedback()
                Task {
                    await viewModel.skipForward(seconds: 10)
                }
            }

            nonisolated func playerViewController(
                _: AVPlayerViewController,
                willEndFullScreenPresentationWithAnimationCoordinator _:
                any UIViewControllerTransitionCoordinator
            ) {
                logger.debug("[VideoPlayer] willEndFullScreenPresentation called")
                Task { @MainActor in
                    // Don't dismiss if we're in PiP mode or restoring from PiP
                    // The restoration presents the controller, which triggers this delegate
                    let pipManager = PiPPlaybackManager.shared
                    if pipManager.isPiPActive || pipManager.isRestoring {
                        logger.debug("[VideoPlayer] Skipping dismiss - PiP active or restoring")
                        return
                    }
                    logger.debug("[VideoPlayer] Dismissing player view")
                    onDismiss()
                }
            }

            nonisolated func playerViewControllerWillStartPictureInPicture(_: AVPlayerViewController) {
                logger.debug("[VideoPlayer] PiP starting")
            }

            nonisolated func playerViewControllerDidStartPictureInPicture(
                _ playerViewController: AVPlayerViewController
            ) {
                logger.debug("[VideoPlayer] PiP started")
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
                logger.debug("[VideoPlayer] PiP stopping")
            }

            nonisolated func playerViewControllerDidStopPictureInPicture(_: AVPlayerViewController) {
                logger.debug("[VideoPlayer] PiP stopped")
                Task { @MainActor in
                    logger.debug("[VideoPlayer] PiP stopped - isRestoring: \(PiPPlaybackManager.shared.isRestoring)")
                    PiPPlaybackManager.shared.pipDidStop()
                }
            }

            nonisolated func playerViewController(
                _: AVPlayerViewController,
                failedToStartPictureInPictureWithError error: Error
            ) {
                logger.debug("[VideoPlayer] PiP failed to start: \(error.localizedDescription)")
            }

            nonisolated func playerViewController(
                _: AVPlayerViewController,
                restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
                @escaping (Bool) -> Void
            ) {
                logger.debug("[VideoPlayer] restoreUserInterface delegate called")
                // Use nonisolated(unsafe) to handle Swift 6 concurrency
                // The completion handler must be called on the main thread, which we ensure
                nonisolated(unsafe) let unsafeCompletion = completionHandler

                Task { @MainActor in
                    logger.debug("[VideoPlayer] Requesting UI restoration from PiPManager")
                    // Store completion handler - it will be called when the new view is ready
                    PiPPlaybackManager.shared.requestRestoreUI(completion: unsafeCompletion)
                }
            }
        }
    }
#endif

// MARK: - Double-Tap Seek View

#if os(iOS)
    /// Visual feedback view for double-tap to seek gesture
    final class DoubleTapSeekView: UIView {
        private let isForward: Bool
        private let feedbackLabel: UILabel
        private let iconImageView: UIImageView
        private let containerStack: UIStackView

        init(isForward: Bool) {
            self.isForward = isForward

            // Create icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
            let iconName = isForward ? "goforward.10" : "gobackward.10"
            iconImageView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconConfig))
            iconImageView.tintColor = .white
            iconImageView.contentMode = .scaleAspectFit

            // Create label
            feedbackLabel = UILabel()
            feedbackLabel.text = "10 seconds"
            feedbackLabel.textColor = .white
            feedbackLabel.font = .systemFont(ofSize: 13, weight: .medium)
            feedbackLabel.textAlignment = .center

            // Create container stack
            containerStack = UIStackView(arrangedSubviews: [iconImageView, feedbackLabel])
            containerStack.axis = .vertical
            containerStack.alignment = .center
            containerStack.spacing = 4
            containerStack.alpha = 0

            super.init(frame: .zero)

            setupView()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setupView() {
            // Transparent background - taps pass through to AVPlayerViewController
            backgroundColor = .clear

            addSubview(containerStack)
            containerStack.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                containerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
                containerStack.centerXAnchor.constraint(equalTo: centerXAnchor)
            ])

            // Accessibility
            isAccessibilityElement = true
            accessibilityLabel = isForward
                ? "Double-tap to skip forward 10 seconds"
                : "Double-tap to skip back 10 seconds"
            accessibilityTraits = .button
        }

        func showFeedback() {
            // Animate feedback appearance
            UIView.animate(withDuration: 0.15) {
                self.containerStack.alpha = 1
                self.containerStack.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } completion: { _ in
                UIView.animate(withDuration: 0.3, delay: 0.3, options: []) {
                    self.containerStack.alpha = 0
                    self.containerStack.transform = .identity
                }
            }
        }

        // Allow taps to pass through when not on interactive elements
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            // Only respond to taps on this view, not subviews
            return result == self ? self : nil
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
