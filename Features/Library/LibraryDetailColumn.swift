import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

/// Detail column for `LibraryView`'s `NavigationSplitView` (iPad / Mac
/// Designed for iPad). Given the split view's current `MediaItem.ID`
/// selection, resolves it back to a full `MediaItem` and renders
/// `MediaDetailView` for it.
///
/// The column owns its own `NavigationStack` so pushes that originate
/// inside the detail (cast member → `PersonDetailView`, filmography item →
/// `MediaDetailView`) stay in this column; the home column's stack and its
/// destinations are not visible from here. Changing the selection pops the
/// column back to its root.
///
/// Selection almost always resolves synchronously from data the view model
/// has already loaded (`mediaItems`, `continueWatching`, `latestItems`);
/// when an id isn't present in any of those, it falls back to
/// `viewModel.getItemDetails(id:)`.
struct LibraryDetailColumn: View {
    let selectedItemID: MediaItem.ID?
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject private var appState: AppState
    @State private var path = NavigationPath()
    @State private var fetchedItem: MediaItem?
    @State private var isFetching = false

    /// Cheap, synchronous lookup across the view model's already-loaded
    /// item collections.
    private var knownItem: MediaItem? {
        guard let selectedItemID else { return nil }
        return viewModel.mediaItems.first { $0.id == selectedItemID }
            ?? viewModel.continueWatching.first { $0.id == selectedItemID }
            ?? viewModel.latestItems.first { $0.id == selectedItemID }
    }

    private var resolvedItem: MediaItem? {
        knownItem ?? (fetchedItem?.id == selectedItemID ? fetchedItem : nil)
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: MediaItem.self) { item in
                    MediaDetailView(item: item, source: .library, viewModel: viewModel)
                }
                .navigationDestination(for: MediaItem.Person.self) { person in
                    PersonDetailView(person: person, appState: appState)
                }
        }
        .task(id: selectedItemID) { await loadIfNeeded() }
        .onChange(of: selectedItemID) {
            path = NavigationPath()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let item = resolvedItem {
            MediaDetailView(item: item, source: .library, viewModel: viewModel)
                .id(item.id)
        } else if isFetching {
            LoadingView(message: "Loading...")
        } else {
            EmptyContentView(
                title: "Select a Title",
                systemImage: "square.stack",
                description: "Choose something from your library to see its details."
            )
        }
    }

    /// Fetches the selected item over the network only when it isn't
    /// already present in one of the view model's loaded collections.
    private func loadIfNeeded() async {
        fetchedItem = nil
        guard let selectedItemID, knownItem == nil else {
            isFetching = false
            return
        }
        isFetching = true
        fetchedItem = await viewModel.getItemDetails(id: selectedItemID)
        isFetching = false
    }
}
