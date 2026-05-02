import SwiftUI

/// A placeholder skeleton card that mimics MediaCard dimensions during loading
public struct SkeletonCard: View {
    public let aspectRatio: CGFloat
    public let cornerRadius: CGFloat

    public init(aspectRatio: CGFloat = 2 / 3, cornerRadius: CGFloat = 8) {
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster placeholder
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.skeletonFill)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .shimmer()

            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeletonFill)
                .frame(height: 14)
                .shimmer()

            // Subtitle placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeletonFill)
                .frame(height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 40)
                .shimmer()
        }
    }
}

/// A horizontal scrolling row of skeleton cards with a title header
public struct SkeletonCardRow: View {
    public let title: String
    public let cardCount: Int
    public let cardWidth: CGFloat
    public let aspectRatio: CGFloat

    public init(
        title: String,
        cardCount: Int = 5,
        cardWidth: CGFloat = 140,
        aspectRatio: CGFloat = 2 / 3
    ) {
        self.title = title
        self.cardCount = cardCount
        self.cardWidth = cardWidth
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(0 ..< cardCount, id: \.self) { _ in
                        SkeletonCard(aspectRatio: aspectRatio)
                            .frame(width: cardWidth)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private extension Color {
    static var skeletonFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}

#Preview {
    VStack(spacing: 32) {
        SkeletonCardRow(title: "Continue Watching", cardCount: 4, cardWidth: 140)
        SkeletonCardRow(title: "Recently Added", cardCount: 5, cardWidth: 140)
    }
    .padding(.vertical)
}
