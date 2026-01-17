import SwiftUI

/// Inline tip card for first-time user guidance
public struct OnboardingTipView: View {
    public let title: String
    public let description: String
    public let icon: String
    public let iconColor: Color

    public init(
        title: String,
        description: String,
        icon: String = "lightbulb.fill",
        iconColor: Color = .yellow
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        OnboardingTipView(
            title: "Getting Started",
            description: "Your library is syncing. Explore the Discover tab to find new content."
        )

        OnboardingTipView(
            title: "Pro Tip",
            description: "Long press any item to see more options like marking as watched.",
            icon: "hand.tap.fill",
            iconColor: .blue
        )
    }
    .padding()
}
