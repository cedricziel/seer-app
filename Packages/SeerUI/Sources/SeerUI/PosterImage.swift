import Kingfisher
import SwiftUI

/// A view for displaying poster images with loading and error states
public struct PosterImage: View {
    public let url: URL?
    public let aspectRatio: CGFloat
    public let cornerRadius: CGFloat

    public init(url: URL?, aspectRatio: CGFloat = 2 / 3, cornerRadius: CGFloat = 8) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        GeometryReader { geometry in
            KFImage(url)
                .placeholder {
                    placeholderView
                }
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.posterFill)
        )
        .accessibilityHidden(true)
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.posterFill)
            .overlay {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
    }
}

/// A backdrop image view for detail screens
public struct BackdropImage: View {
    public let url: URL?
    public let height: CGFloat

    public init(url: URL?, height: CGFloat = 220) {
        self.url = url
        self.height = height
    }

    public var body: some View {
        KFImage(url)
            .placeholder {
                Rectangle()
                    .fill(Color.posterFill)
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: height)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.posterScrim.opacity(0.8), Color.posterScrim],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Cross-platform colors

private extension Color {
    static var posterFill: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color.gray.opacity(0.2)
        #endif
    }

    static var posterScrim: Color {
        #if os(iOS)
            Color(uiColor: .systemBackground)
        #else
            Color.black
        #endif
    }
}

#Preview {
    VStack(spacing: 20) {
        PosterImage(url: nil)
            .frame(width: 150)

        BackdropImage(url: nil)
    }
}
