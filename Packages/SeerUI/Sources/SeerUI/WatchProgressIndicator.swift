import SwiftUI

/// A progress bar indicator for showing watch progress on media
public struct WatchProgressIndicator: View {
    public let progress: Double
    public let height: CGFloat
    public let backgroundColor: Color
    public let progressColor: Color

    /// Create a watch progress indicator
    /// - Parameters:
    ///   - progress: Progress value between 0 and 1
    ///   - height: Height of the progress bar
    ///   - backgroundColor: Background track color
    ///   - progressColor: Filled progress color
    public init(
        progress: Double,
        height: CGFloat = 3,
        backgroundColor: Color = .white.opacity(0.3),
        progressColor: Color = .accentColor
    ) {
        self.progress = min(max(progress, 0), 1) // Clamp between 0-1
        self.height = height
        self.backgroundColor = backgroundColor
        self.progressColor = progressColor
    }

    /// Convenience initializer from playback ticks
    /// - Parameters:
    ///   - positionTicks: Current position in ticks
    ///   - durationTicks: Total duration in ticks
    public init(
        positionTicks: Int64?,
        durationTicks: Int64?,
        height: CGFloat = 3,
        progressColor: Color = .accentColor
    ) {
        let calculatedProgress: Double
        if let position = positionTicks,
           let duration = durationTicks,
           duration > 0 {
            calculatedProgress = Double(position) / Double(duration)
        } else {
            calculatedProgress = 0
        }
        self.init(
            progress: calculatedProgress,
            height: height,
            progressColor: progressColor
        )
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(backgroundColor)

                // Progress fill
                Rectangle()
                    .fill(progressColor)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: height)
    }
}

/// A modifier to add watch progress to any view
public struct WatchProgressOverlayModifier: ViewModifier {
    public let progress: Double?
    public let alignment: Alignment
    public let height: CGFloat

    public init(
        progress: Double?,
        alignment: Alignment = .bottom,
        height: CGFloat = 3
    ) {
        self.progress = progress
        self.alignment = alignment
        self.height = height
    }

    public func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            if let progress, progress > 0 {
                WatchProgressIndicator(progress: progress, height: height)
            }
        }
    }
}

public extension View {
    /// Add a watch progress overlay to a view
    /// - Parameters:
    ///   - progress: Progress value between 0 and 1, or nil to hide
    ///   - alignment: Where to position the progress bar
    ///   - height: Height of the progress bar
    func watchProgress(
        _ progress: Double?,
        alignment: Alignment = .bottom,
        height: CGFloat = 3
    ) -> some View {
        modifier(WatchProgressOverlayModifier(
            progress: progress,
            alignment: alignment,
            height: height
        ))
    }
}

#Preview {
    VStack(spacing: 20) {
        // Basic progress indicators
        WatchProgressIndicator(progress: 0.25)
        WatchProgressIndicator(progress: 0.5)
        WatchProgressIndicator(progress: 0.75)
        WatchProgressIndicator(progress: 1.0)

        // On a card
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray)
            .frame(width: 140, height: 200)
            .watchProgress(0.6)

        // From ticks
        WatchProgressIndicator(
            positionTicks: 30_000_000_000,
            durationTicks: 100_000_000_000
        )
    }
    .padding()
}
