#if os(macOS)
    import AVKit
    import DownloadClient
    import JellyfinClient
    import SeerCore
    import SwiftUI

    public struct VideoPlayerView: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(DownloadManager.self) private var downloadManager: DownloadManager?
        @State private var viewModel: VideoPlayerViewModel
        private let startPositionTicks: Int64

        public init(
            item: MediaItem,
            appState: AppState,
            startPositionTicks: Int64 = 0,
            downloadServerID: String? = nil,
            existingPlayer: AVPlayer? = nil,
            onPiPStart _: (() -> Void)? = nil
        ) {
            self.startPositionTicks = startPositionTicks
            _viewModel = State(wrappedValue: VideoPlayerViewModel(
                item: item,
                appState: appState,
                startPositionTicks: startPositionTicks,
                existingPlayer: existingPlayer,
                downloadServerID: downloadServerID
            ))
        }

        public var body: some View {
            ZStack {
                Color.black
                MacPlayerView(player: viewModel.player, showsControls: viewModel.errorMessage == nil)
                if viewModel.isBuffering, viewModel.player == nil {
                    ProgressView("Loading video")
                }
                if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Text("Playback Error").font(.title2)
                        Text(error)
                        Button("Retry") {
                            viewModel.loadAndPlay(startPositionTicks: startPositionTicks)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .frame(minWidth: 640, minHeight: 360)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .onAppear {
                viewModel.downloadManager = downloadManager
                viewModel.loadAndPlay(startPositionTicks: startPositionTicks)
            }
            .onDisappear { viewModel.stop() }
        }
    }

    private struct MacPlayerView: NSViewRepresentable {
        let player: AVPlayer?
        let showsControls: Bool

        func makeNSView(context _: Context) -> AVPlayerView {
            let view = AVPlayerView()
            view.controlsStyle = showsControls ? .floating : .none
            view.showsFullScreenToggleButton = true
            return view
        }

        func updateNSView(_ view: AVPlayerView, context _: Context) {
            view.player = player
            view.controlsStyle = showsControls ? .floating : .none
        }
    }

#elseif os(tvOS)
    import AVKit
    import JellyfinClient
    import SeerCore
    import SwiftUI

    public struct VideoPlayerView: View {
        @Environment(\.dismiss) private var dismiss
        private let item: MediaItem
        private let appState: AppState
        private let startPositionTicks: Int64
        private let downloadServerID: String?

        public init(
            item: MediaItem,
            appState: AppState,
            startPositionTicks: Int64 = 0,
            downloadServerID: String? = nil,
            existingPlayer _: AVPlayer? = nil,
            onPiPStart _: (() -> Void)? = nil
        ) {
            self.item = item
            self.appState = appState
            self.startPositionTicks = startPositionTicks
            self.downloadServerID = downloadServerID
        }

        public var body: some View {
            TVPlayerView(
                item: item,
                appState: appState,
                startPositionTicks: startPositionTicks,
                downloadServerID: downloadServerID,
                onDismiss: { dismiss() }
            )
        }
    }
#endif
