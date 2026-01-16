import JellyseerrClient
import SeerCore
import SeerUI
import SwiftUI

/// View for displaying and managing media requests
struct RequestsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        RequestsContentView(appState: appState)
    }
}

/// Internal view that creates the view model with the correct AppState
private struct RequestsContentView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: RequestsViewModel
    @State private var selectedRequestDetails: MediaRequest?

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: RequestsViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isJellyseerrConfigured {
                    notConfiguredView
                } else if viewModel.isLoading, viewModel.requests.isEmpty {
                    LoadingView(message: "Loading requests...")
                } else if let error = viewModel.errorMessage, viewModel.requests.isEmpty {
                    ErrorView(error: error) {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                } else if viewModel.requests.isEmpty {
                    EmptyContentView(
                        title: "No Requests",
                        systemImage: "list.bullet.clipboard",
                        description: "Your media requests will appear here"
                    )
                } else {
                    requestsList
                }
            }
            .navigationTitle("Requests")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ServerSwitcherButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }, label: {
                        Image(systemName: "arrow.clockwise")
                    })
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $selectedRequestDetails) { request in
                RequestDetailsSheet(request: request)
            }
        }
        .task {
            if viewModel.isJellyseerrConfigured {
                await viewModel.loadRequests()
            }
        }
        .onChange(of: appState.activeServerID) {
            Task {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Not Configured View

    private var notConfiguredView: some View {
        EmptyContentView(
            title: "Jellyseerr Not Configured",
            systemImage: "server.rack",
            description: "Configure Jellyseerr in settings to view your requests."
        )
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Section("Filter") {
                ForEach(RequestsViewModel.RequestFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        viewModel.selectedFilter = filter
                        Task {
                            await viewModel.filterChanged()
                        }
                    }, label: {
                        HStack {
                            Text(filter.rawValue)
                            if viewModel.selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    })
                }
            }

            Section("Sort") {
                ForEach(RequestsViewModel.RequestSort.allCases, id: \.self) { sort in
                    Button(action: {
                        viewModel.selectedSort = sort
                        Task {
                            await viewModel.filterChanged()
                        }
                    }, label: {
                        HStack {
                            Text(sort.rawValue)
                            if viewModel.selectedSort == sort {
                                Image(systemName: "checkmark")
                            }
                        }
                    })
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - Requests List

    private var requestsList: some View {
        List {
            ForEach(viewModel.requests) { request in
                RequestRowView(
                    request: request,
                    onViewDetails: { selectedRequestDetails = request },
                    onCancelRequest: {
                        Task {
                            try? await viewModel.cancelRequest(request)
                        }
                    }
                )
                .onAppear {
                    Task {
                        await viewModel.loadMoreRequestsIfNeeded(currentRequest: request)
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Request Row View

struct RequestRowView: View {
    let request: MediaRequest
    var onViewDetails: (() -> Void)?
    var onCancelRequest: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Poster image or placeholder
            posterView

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.media.displayTitle ?? "Request #\(request.id)")
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    MediaTypeBadge(type: request.type == .movie ? .movie : .tvShow)
                    statusBadge
                }

                Text("Requested by \(request.requestedBy.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(request.formattedCreatedAt)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Status icon
            statusIcon
        }
        .padding(.vertical, 4)
        .contextMenu {
            requestContextMenu
        }
    }

    @ViewBuilder
    private var requestContextMenu: some View {
        // View Details
        if let onViewDetails {
            Button {
                onViewDetails()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }

        // Cancel Request (only for pending requests)
        if canCancel, let onCancelRequest {
            Divider()

            Button(role: .destructive) {
                onCancelRequest()
            } label: {
                Label("Cancel Request", systemImage: "xmark.circle")
            }
        }
    }

    private var canCancel: Bool {
        request.status == .pending
    }

    @ViewBuilder
    private var posterView: some View {
        if let posterPath = request.media.posterPath {
            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                posterPlaceholder
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .frame(width: 50, height: 75)
            .overlay {
                Image(systemName: request.type == .movie ? "film" : "tv")
                    .foregroundStyle(.secondary)
            }
    }

    private var statusBadge: some View {
        Group {
            switch request.status {
            case .pending:
                RequestStatusBadge(status: .pending, style: .full)
            case .approved:
                RequestStatusBadge(status: .approved, style: .full)
            case .declined:
                RequestStatusBadge(status: .declined, style: .full)
            case .available:
                RequestStatusBadge(status: .available, style: .full)
            case .processing:
                RequestStatusBadge(status: .processing, style: .full)
            }
        }
    }

    private var statusIcon: some View {
        Image(systemName: request.status.iconName)
            .font(.title2)
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch request.status {
        case .pending: .orange
        case .approved: .blue
        case .declined: .red
        case .available: .green
        case .processing: .purple
        }
    }
}

// MARK: - Request Details Sheet

struct RequestDetailsSheet: View {
    let request: MediaRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Details") {
                    LabeledContent("Title", value: request.media.displayTitle ?? "Unknown")
                    LabeledContent("Type", value: request.type == .movie ? "Movie" : "TV Show")
                    LabeledContent("Status", value: request.status.displayName)
                    LabeledContent("Requested by", value: request.requestedBy.displayName)
                    LabeledContent("Requested", value: request.formattedCreatedAt)
                }
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RequestsView()
        .environmentObject(AppState())
}
