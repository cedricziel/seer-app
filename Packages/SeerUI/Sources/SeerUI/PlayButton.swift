import SwiftUI

/// A styled play/resume button for media playback
public struct PlayButton: View {
    public let title: String
    public let icon: String
    public let action: () -> Void

    public init(
        title: String = "Play",
        icon: String = "play.fill",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    /// Convenience initializer for resume functionality
    public init(
        hasProgress: Bool,
        action: @escaping () -> Void
    ) {
        title = hasProgress ? "Resume" : "Play"
        icon = "play.fill"
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// A circular play button overlay for use on media cards
public struct PlayButtonOverlay: View {
    public let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        PlayButton(title: "Play", action: {})
        PlayButton(hasProgress: true, action: {})
        PlayButton(hasProgress: false, action: {})

        HStack {
            Text("Card with overlay")
            Spacer()
            PlayButtonOverlay(action: {})
        }
        .padding()
        .background(Color.gray)
    }
    .padding()
}
