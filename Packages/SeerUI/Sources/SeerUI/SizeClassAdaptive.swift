import SwiftUI

/// Renders one of two branches depending on the current horizontal size
/// class, without ever instantiating the branch that isn't shown.
///
/// Use this for layouts that differ structurally between compact width
/// (iPhone) and regular width (iPad, Mac Designed for iPad) — for example
/// switching between a `NavigationStack` and a `NavigationSplitView`. Only
/// the matching `@ViewBuilder` closure is called; the other is never
/// evaluated.
public struct SizeClassAdaptive<Compact: View, Regular: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let compact: () -> Compact
    private let regular: () -> Regular

    /// - Parameters:
    ///   - compact: Built and shown when the horizontal size class is
    ///     `.compact` or unknown.
    ///   - regular: Built and shown when the horizontal size class is
    ///     `.regular`.
    public init(
        @ViewBuilder compact: @escaping () -> Compact,
        @ViewBuilder regular: @escaping () -> Regular
    ) {
        self.compact = compact
        self.regular = regular
    }

    public var body: some View {
        if horizontalSizeClass == .regular {
            regular()
        } else {
            compact()
        }
    }
}
