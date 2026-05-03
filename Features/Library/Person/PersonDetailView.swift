import JellyfinClient
import Kingfisher
import SeerCore
import SeerUI
import SwiftUI

struct PersonDetailView: View {
    let person: MediaItem.Person
    @StateObject private var viewModel: PersonDetailViewModel

    init(person: MediaItem.Person, appState: AppState) {
        self.person = person
        _viewModel = StateObject(wrappedValue: PersonDetailViewModel(person: person, appState: appState))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PersonDetailHeader(
                    name: viewModel.displayName,
                    role: person.role,
                    headshotURL: viewModel.headshotURL(),
                    lifespan: PersonDetailHeader.lifespan(
                        born: viewModel.person?.premiereDate,
                        died: viewModel.person?.endDate
                    ),
                    birthplace: viewModel.person?.productionLocations?.first
                )

                if let overview = viewModel.person?.overview, !overview.isEmpty {
                    PersonBiographyView(overview: overview)
                }

                PersonFilmographyView(
                    state: filmographyState,
                    personName: viewModel.displayName,
                    imageURL: { viewModel.imageURL(for: $0) }
                )
            }
            .padding()
        }
        .navigationTitle(viewModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private var filmographyState: PersonFilmographyView.State {
        if viewModel.isLoading, viewModel.filmography.isEmpty {
            return .loading
        }
        if let error = viewModel.errorMessage, viewModel.filmography.isEmpty {
            return .error(error)
        }
        if viewModel.filmography.isEmpty {
            return .empty
        }
        return .loaded(viewModel.filmography)
    }
}

// MARK: - Header

struct PersonDetailHeader: View {
    let name: String
    let role: String?
    let headshotURL: URL?
    let lifespan: String?
    let birthplace: String?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            headshot
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let lifespan {
                    Text(lifespan)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let birthplace {
                    Text(birthplace)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var headshot: some View {
        if let headshotURL {
            KFImage(headshotURL)
                .placeholder { headshotPlaceholder }
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            headshotPlaceholder
        }
    }

    private var headshotPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    static func lifespan(born: Date?, died: Date?) -> String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        switch (born, died) {
        case let (born?, died?):
            return "\(formatter.string(from: born)) – \(formatter.string(from: died))"
        case let (born?, nil):
            return "Born \(formatter.string(from: born))"
        default:
            return nil
        }
    }
}

// MARK: - Biography

struct PersonBiographyView: View {
    let overview: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Biography")
                .font(.headline)
            Text(overview)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Filmography

struct PersonFilmographyView: View {
    enum State {
        case loading
        case loaded([MediaItem])
        case empty
        case error(String)
    }

    let state: State
    let personName: String
    let imageURL: (MediaItem) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filmography")
                .font(.headline)

            switch state {
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 24)
            case let .error(message):
                SectionEmptyView(message: message, systemImage: "exclamationmark.triangle")
            case .empty:
                SectionEmptyView(
                    message: "No titles in your library feature \(personName).",
                    systemImage: "film.stack"
                )
            case let .loaded(items):
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                MediaCard(
                                    title: item.name,
                                    subtitle: item.year.map { String($0) },
                                    imageURL: imageURL(item)
                                )
                                .frame(width: 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
