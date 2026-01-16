import DownloadClient
import JellyfinClient
import JellyseerrClient
import PlaybackClient
import SeerCore
import SeerUI
import SwiftUI

/// Indicates whether a media item came from the library or search results
enum MediaItemSource {
    case library // From Jellyfin library (already exists)
    case search // From Jellyseerr search (requestable)
}

/// Detail view for a media item
struct MediaDetailView: View {
    let item: MediaItem
    let source: MediaItemSource
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var appState: AppState

    @Environment(DownloadManager.self) var downloadManager: DownloadManager?

    @State private var isRequestingMedia: Bool = false
    @State private var requestError: String?
    @State private var showRequestSuccess: Bool = false
    @State var seriesViewModel: SeriesDetailViewModel?
    @State var showPlayer: Bool = false
    @State var selectedEpisodeForPlayback: MediaItem?
    @State var downloadState: DownloadButtonState = .notDownloaded
    @State var episodeDownloadStates: [String: DownloadButtonState] = [:]
    @State var selectedEpisodeForDetail: MediaItem?
    @State var showEpisodeDetail: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Backdrop
                BackdropImage(url: viewModel.imageURL(for: item, type: .backdrop))

                // Content
                VStack(alignment: .leading, spacing: 16) {
                    // Title and metadata
                    headerSection

                    // Play button (for movies and episodes from library)
                    if source == .library, item.type == .movie || item.type == .episode {
                        playButton
                    }

                    // Overview
                    if let overview = item.overview {
                        overviewSection(overview)
                    }

                    // Genres
                    if let genres = item.genres, !genres.isEmpty {
                        genresSection(genres)
                    }

                    // Cast
                    if let people = item.people, !people.isEmpty {
                        castSection(people)
                    }

                    // Seasons section for TV series from library
                    if item.type == .series, source == .library {
                        seasonsSection
                    }

                    // Request Button (only for search results, if Jellyseerr is configured)
                    if source == .search, appState.jellyseerrServerURL != nil {
                        requestSection
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard item.type == .series, source == .library else { return }
            seriesViewModel = SeriesDetailViewModel(series: item, appState: appState)
            await seriesViewModel?.loadSeasons()
        }
        .alert("Request Submitted", isPresented: $showRequestSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your request has been submitted successfully.")
        }
        .alert("Request Failed", isPresented: .init(
            get: { requestError != nil },
            set: { if !$0 { requestError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(requestError ?? "An error occurred")
        }
        .fullScreenCover(isPresented: $showPlayer) {
            let playbackItem = selectedEpisodeForPlayback ?? item
            VideoPlayerView(
                item: playbackItem,
                appState: appState,
                startPositionTicks: playbackItem.userData?.playbackPositionTicks ?? 0,
                onPiPStart: { showPlayer = false }
            )
        }
        .onChange(of: showPlayer) { _, isShowing in
            if !isShowing {
                selectedEpisodeForPlayback = nil
            }
        }
        .sheet(isPresented: $showEpisodeDetail) {
            if let episode = selectedEpisodeForDetail {
                EpisodeDetailSheet(
                    episode: episode,
                    imageURL: viewModel.imageURL(for: episode, type: .primary),
                    downloadState: episodeDownloadStates[episode.id] ?? .notDownloaded,
                    onPlay: {
                        showEpisodeDetail = false
                        selectedEpisodeForPlayback = episode
                        showPlayer = true
                    },
                    onDownload: {
                        Task { await downloadEpisode(episode) }
                    }
                )
            }
        }
    }

    /// Whether the item has playback progress
    var hasProgress: Bool {
        guard let ticks = item.userData?.playbackPositionTicks else { return false }
        return ticks > 0
    }

    // MARK: - Request Section

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            Button(action: {
                Task {
                    await requestMedia()
                }
            }, label: {
                HStack {
                    if isRequestingMedia {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(isRequestingMedia ? "Requesting..." : "Request in Jellyseerr")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            })
            .disabled(isRequestingMedia)
        }
    }

    // MARK: - Actions

    private func requestMedia() async {
        guard let serverURL = appState.jellyseerrServerURL,
              let apiKey = appState.jellyseerrAPIKey
        else {
            requestError = "Jellyseerr not configured"
            return
        }

        // Get TMDB ID from provider IDs
        guard let tmdbIDString = item.providerIds?["Tmdb"],
              let tmdbID = Int(tmdbIDString)
        else {
            requestError = "Unable to find TMDB ID for this media"
            return
        }

        isRequestingMedia = true

        do {
            let service = JellyseerrService(serverURL: serverURL, apiKey: apiKey)
            _ = try await service.createRequest(
                mediaType: item.type == .movie ? .movie : .tvShow,
                mediaId: tmdbID
            )
            showRequestSuccess = true
        } catch {
            requestError = error.localizedDescription
        }

        isRequestingMedia = false
    }
}

#Preview {
    NavigationStack {
        MediaDetailView(
            item: MediaItem(
                id: "1",
                name: "Test Movie",
                originalTitle: nil,
                overview: "This is a test movie description that explains what the movie is about.",
                year: 2024,
                communityRating: 8.5,
                officialRating: "PG-13",
                runTimeTicks: 72_000_000_000,
                type: .movie,
                seriesName: nil,
                seriesId: nil,
                seasonName: nil,
                indexNumber: nil,
                parentIndexNumber: nil,
                premiereDate: nil,
                endDate: nil,
                isFolder: false,
                playedPercentage: nil,
                userData: nil,
                imageBlurHashes: nil,
                backdropImageTags: nil,
                genres: ["Action", "Adventure", "Sci-Fi"],
                studios: nil,
                people: nil,
                providerIds: nil
            ),
            source: .library,
            viewModel: LibraryViewModel(appState: AppState())
        )
        .environmentObject(AppState())
    }
}
