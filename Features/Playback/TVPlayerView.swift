import AVKit
import JellyfinClient
import PlaybackClient
import SeerCore
import SwiftUI

#if os(tvOS)
    /// Native tvOS video player using AVPlayerViewController for Siri Remote support
    public struct TVPlayerView: UIViewControllerRepresentable {
        private let item: MediaItem
        private let appState: AppState
        private let startPositionTicks: Int64
        private let onDismiss: () -> Void

        @State private var viewModel: VideoPlayerViewModel

        public init(
            item: MediaItem,
            appState: AppState,
            startPositionTicks: Int64 = 0,
            onDismiss: @escaping () -> Void
        ) {
            self.item = item
            self.appState = appState
            self.startPositionTicks = startPositionTicks
            self.onDismiss = onDismiss
            _viewModel = State(wrappedValue: VideoPlayerViewModel(
                item: item,
                appState: appState,
                startPositionTicks: startPositionTicks
            ))
        }

        public func makeUIViewController(context: Context) -> AVPlayerViewController {
            let controller = AVPlayerViewController()
            controller.delegate = context.coordinator

            Task {
                await viewModel.loadMedia(startPositionTicks: startPositionTicks)
                if let player = viewModel.player {
                    await MainActor.run {
                        controller.player = player
                        player.play()
                    }
                }
            }

            return controller
        }

        public func updateUIViewController(_ uiViewController: AVPlayerViewController, context _: Context) {
            // Update player if needed
            if uiViewController.player !== viewModel.player {
                uiViewController.player = viewModel.player
            }
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator(onDismiss: onDismiss, viewModel: viewModel)
        }

        public class Coordinator: NSObject, AVPlayerViewControllerDelegate {
            let onDismiss: () -> Void
            let viewModel: VideoPlayerViewModel

            init(onDismiss: @escaping () -> Void, viewModel: VideoPlayerViewModel) {
                self.onDismiss = onDismiss
                self.viewModel = viewModel
            }

            public func playerViewControllerDidStopPictureInPicture(_: AVPlayerViewController) {
                // Handle PiP stop
            }

            public func playerViewControllerWillBeginDismissalTransition(_: AVPlayerViewController) {
                Task { @MainActor in
                    viewModel.stop()
                }
            }

            public func playerViewControllerDidEndDismissalTransition(_: AVPlayerViewController) {
                onDismiss()
            }
        }
    }
#else
    /// Placeholder for non-tvOS platforms - use VideoPlayerView instead
    public struct TVPlayerView: View {
        let item: MediaItem
        let appState: AppState
        let startPositionTicks: Int64
        let onDismiss: () -> Void

        public init(
            item: MediaItem,
            appState: AppState,
            startPositionTicks: Int64 = 0,
            onDismiss: @escaping () -> Void
        ) {
            self.item = item
            self.appState = appState
            self.startPositionTicks = startPositionTicks
            self.onDismiss = onDismiss
        }

        public var body: some View {
            VideoPlayerView(
                item: item,
                appState: appState,
                startPositionTicks: startPositionTicks
            )
        }
    }
#endif
