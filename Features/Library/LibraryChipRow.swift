import JellyfinClient
import SwiftUI

/// SF Symbol mapping for a library's collection type, shared by the chip
/// row and any grid screens that need the same icon (film / tv /
/// music.note / book / folder).
func libraryIcon(for type: Library.CollectionType?) -> String {
    switch type {
    case .movies: "film"
    case .tvshows: "tv"
    case .music: "music.note"
    case .books: "book"
    default: "folder"
    }
}

/// A horizontally scrolling row of library capsules for the Library home
/// screen. Tapping a chip only reports the selection via `onSelect` — it
/// is up to the caller to push the library grid screen.
struct LibraryChipRow: View {
    let libraries: [Library]
    let onSelect: (Library) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(libraries) { library in
                    chip(for: library)
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(for library: Library) -> some View {
        Button {
            onSelect(library)
        } label: {
            chipLabel(for: library)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }

    private func chipLabel(for library: Library) -> some View {
        HStack(spacing: 8) {
            Image(systemName: libraryIcon(for: library.collectionType))
            Text(library.name)
                .lineLimit(1)
        }
        #if os(tvOS)
        .font(.headline)
        .padding(.horizontal, 24)
        .frame(height: 60)
        #else
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .frame(height: 44)
        #endif
        .background(Capsule().fill(Color.libraryChipFill))
    }
}

private extension Color {
    static var libraryChipFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}

/// `Library` has no public memberwise initializer (its stored properties are
/// public, but Swift caps a synthesized memberwise init at `internal` when
/// the struct declares no explicit `init`), so cross-module preview data is
/// built by decoding JSON instead — `Library`'s `Codable` conformance is
/// synthesized at the type's own `public` access level.
private func previewLibraries() -> [Library] {
    let json = """
    [
        {"Id": "1", "Name": "Movies", "CollectionType": "movies"},
        {"Id": "2", "Name": "TV Shows", "CollectionType": "tvshows"},
        {"Id": "3", "Name": "Music", "CollectionType": "music"}
    ]
    """
    guard let data = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([Library].self, from: data)) ?? []
}

#Preview {
    LibraryChipRow(
        libraries: previewLibraries(),
        onSelect: { _ in }
    )
}
