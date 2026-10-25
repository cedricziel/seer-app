import SwiftUI

/// A full-width 16:9 shimmering placeholder sized like the Continue
/// Watching hero card, shown while the first continue-watching item loads.
public struct SkeletonHeroRow: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.skeletonHeroFill)
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .shimmer()
    }
}

/// A single 180×101 landscape skeleton card, matching the size of the
/// non-hero Continue Watching cards, with title/subtitle placeholder lines.
public struct SkeletonLandscapeCard: View {
    #if os(tvOS)
        public static let width: CGFloat = 405
        public static let height: CGFloat = 228
    #else
        public static let width: CGFloat = 180
        public static let height: CGFloat = 101
    #endif

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.skeletonHeroFill)
                .frame(width: Self.width, height: Self.height)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeletonHeroFill)
                .frame(width: Self.width * 0.75, height: 12)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeletonHeroFill)
                .frame(width: Self.width * 0.5, height: 10)
                .shimmer()
        }
    }
}

/// A horizontally scrolling row of `SkeletonLandscapeCard` placeholders,
/// used for the non-hero Continue Watching items while loading.
public struct SkeletonLandscapeRow: View {
    public let cardCount: Int

    public init(cardCount: Int = 4) {
        self.cardCount = cardCount
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(0 ..< cardCount, id: \.self) { _ in
                    SkeletonLandscapeCard()
                }
            }
            .padding(.horizontal)
        }
    }
}

private extension Color {
    static var skeletonHeroFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SkeletonHeroRow()
            .padding(.horizontal)
        SkeletonLandscapeRow()
    }
    .padding(.vertical)
}
