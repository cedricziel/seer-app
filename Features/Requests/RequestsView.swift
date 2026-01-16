import JellyseerrClient
import SeerCore
import SeerUI
import SwiftUI

/// View for displaying and managing media requests
struct RequestsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RequestsViewModel

    init() {
        _viewModel = StateObject(wrappedValue: RequestsViewModel(appState: AppState()))
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
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            if viewModel.isJellyseerrConfigured {
                await viewModel.loadRequests()
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
                    }) {
                        HStack {
                            Text(filter.rawValue)
                            if viewModel.selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Sort") {
                ForEach(RequestsViewModel.RequestSort.allCases, id: \.self) { sort in
                    Button(action: {
                        viewModel.selectedSort = sort
                        Task {
                            await viewModel.filterChanged()
                        }
                    }) {
                        HStack {
                            Text(sort.rawValue)
                            if viewModel.selectedSort == sort {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
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
                RequestRowView(request: request)
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

    var body: some View {
        HStack(spacing: 12) {
            // Placeholder poster
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 75)
                .overlay {
                    Image(systemName: request.type == .movie ? "film" : "tv")
                        .foregroundStyle(.secondary)
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Request #\(request.id)")
                    .font(.headline)

                HStack(spacing: 8) {
                    MediaTypeBadge(type: request.type == .movie ? .movie : .tv)
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

#Preview {
    RequestsView()
        .environmentObject(AppState())
}
