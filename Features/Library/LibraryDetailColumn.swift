import JellyfinClient
import SeerCore
import SeerUI
import SwiftUI

/// Detail column for `LibraryView`'s `NavigationSplitView` (iPad / Mac
/// Designed for iPad). Renders `MediaDetailView` for the split view's
/// current selection, or a placeholder when nothing is selected.
///
/// The selection is the full `MediaItem`, not just its id, so an item
/// chosen in a pushed `LibraryGridView` (which owns a separate
/// `LibraryViewModel` and item list) renders immediately without a lookup;
/// `MediaDetailView` fetches the richer detail record itself.
///
/// The column owns its own `NavigationStack` so pushes that originate
/// inside the detail (cast member → `PersonDetailView`, filmography item →
/// `MediaDetailView`) stay in this column; the home column's stack and its
/// destinations are not visible from here. Changing the selection pops the
/// column back to its root.
struct LibraryDetailColumn: View {
    let selectedItem: MediaItem?
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject private var appState: AppState
    @State private var path = NavigationPath()

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
        .onChange(of: selectedItem?.id) {
            path = NavigationPath()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let item = selectedItem {
            MediaDetailView(item: item, source: .library, viewModel: viewModel)
                .id(item.id)
        } else {
            EmptyContentView(
                title: "Select a Title",
                systemImage: "square.stack",
                description: "Choose something from your library to see its details."
            )
        }
    }
}
