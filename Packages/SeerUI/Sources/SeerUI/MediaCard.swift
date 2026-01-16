import Kingfisher
import SwiftUI

/// A card view for displaying media items
public struct MediaCard: View {
    public let title: String
    public let subtitle: String?
    public let imageURL: URL?
    public let aspectRatio: CGFloat
    public let cornerRadius: CGFloat

    public init(
        title: String,
        subtitle: String? = nil,
        imageURL: URL? = nil,
        aspectRatio: CGFloat = 2 / 3,
        cornerRadius: CGFloat = 8
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(url: imageURL, aspectRatio: aspectRatio, cornerRadius: cornerRadius)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A horizontal scrolling row of media cards
public struct MediaCardRow<Content: View>: View {
    public let title: String
    public let content: () -> Content

    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    content()
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MediaCardRow(title: "Continue Watching") {
                ForEach(0 ..< 5, id: \.self) { index in
                    MediaCard(
                        title: "Movie Title \(index + 1)",
                        subtitle: "2024",
                        imageURL: nil
                    )
                    .frame(width: 140)
                }
            }
        }
    }
}
