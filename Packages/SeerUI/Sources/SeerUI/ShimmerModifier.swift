import SwiftUI

/// A view modifier that applies an animated shimmer effect
public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.4), location: 0.5),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                    }
                }
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

public extension View {
    /// Applies an animated shimmer effect to the view
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
