import SwiftUI

public extension Color {
    /// Retains the iOS artwork placeholder color with a fallback for other platforms.
    static var mediaPlaceholder: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.secondary.opacity(0.2)
        #endif
    }
}
