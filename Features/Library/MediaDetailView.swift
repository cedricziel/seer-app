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
    @EnvironmentObject private var appState: AppState

    @State private var isRequestingMedia: Bool = false
    @State private var requestError: String?
    @State private var showRequestSuccess: Bool = false
    @State private var seriesViewModel: SeriesDetailViewModel?
    @State private var showPlayer: Bool = false
    @State private var selectedEpisodeForPlayback: MediaItem?

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
                startPositionTicks: playbackItem.userData?.playbackPositionTicks ?? 0
            )
        }
        .onChange(of: showPlayer) { _, isShowing in
            if !isShowing {
                selectedEpisodeForPlayback = nil
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster
            PosterImage(url: viewModel.imageURL(for: item), cornerRadius: 8)
                .frame(width: 100)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let originalTitle = item.originalTitle, originalTitle != item.name {
                    Text(originalTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if let year = item.year {
                        Text(String(year))
                    }

                    if let runtime = item.formattedRuntime {
                        Text(runtime)
                    }

                    if let rating = item.officialRating {
                        Text(rating)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                // Rating
                if let rating = item.communityRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }

                // Media Type Badge
                MediaTypeBadge(type: item.type == .movie ? .movie : .tvShow)
            }
        }
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button {
            showPlayer = true
        } label: {
            HStack {
                Image(systemName: hasProgress ? "play.fill" : "play.fill")
                Text(hasProgress ? "Resume" : "Play")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Whether the item has playback progress
    private var hasProgress: Bool {
        guard let ticks = item.userData?.playbackPositionTicks else { return false }
        return ticks > 0
    }

    // MARK: - Overview Section

    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)

            Text(overview)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Genres Section

    private func genresSection(_ genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Cast Section

    private func castSection(_ people: [MediaItem.Person]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cast")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(people.prefix(10), id: \.name) { person in
                        VStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                }

                            Text(person.name ?? "Unknown")
                                .font(.caption)
                                .lineLimit(1)

                            if let role = person.role {
                                Text(role)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 80)
                    }
                }
            }
        }
    }

    // MARK: - Seasons Section

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasons")
                .font(.headline)

            if let viewModel = seriesViewModel {
                if viewModel.isLoadingSeasons {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.seasons.isEmpty {
                    Text("No seasons available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.seasons) { season in
                        SeasonDisclosureRow(
                            season: season,
                            episodes: viewModel.episodesBySeason[season.id] ?? [],
                            isExpanded: viewModel.expandedSeasons.contains(season.id),
                            isLoading: viewModel.isLoadingEpisodes[season.id] ?? false,
                            onToggle: {
                                Task {
                                    await viewModel.toggleSeason(season.id)
                                }
                            },
                            imageURL: { viewModel.imageURL(for: $0, type: .thumb) },
                            onPlayEpisode: { episode in
                                selectedEpisodeForPlayback = episode
                                showPlayer = true
                            }
                        )
                    }
                }
            }
        }
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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            ), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }

            size.height = currentY + lineHeight
        }
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
