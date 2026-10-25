import SwiftUI

/// Returns the grid columns to use for a media poster grid at the given
/// horizontal size class.
///
/// Compact width (iPhone, or nil when no size class is known) uses three
/// flexible columns with 14pt spacing between them. Regular width (iPad,
/// Mac Designed for iPad) uses a single adaptive column definition so the
/// grid lays out as many 180pt-minimum columns as fit the available width.
public func mediaGridColumns(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
    switch horizontalSizeClass {
    case .regular:
        [GridItem(.adaptive(minimum: 180))]
    case .compact, nil:
        Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)
    @unknown default:
        Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)
    }
}
