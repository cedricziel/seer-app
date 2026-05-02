import SwiftUI

/// Apple-style What's New modal view
public struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    public let appName: String
    public let features: [WhatsNewFeature]
    public let onContinue: () -> Void

    public init(
        appName: String,
        features: [WhatsNewFeature],
        onContinue: @escaping () -> Void
    ) {
        self.appName = appName
        self.features = features
        self.onContinue = onContinue
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 24)
                    .padding(.bottom, 32)

                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(features) { feature in
                            WhatsNewFeatureRow(feature: feature)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onContinue()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("AppIcon")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                }
                .accessibilityHidden(true)

            Text("What's New in \(appName)")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
    }

    private var continueButton: some View {
        Button {
            onContinue()
            dismiss()
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// A row displaying a single feature in the What's New modal
public struct WhatsNewFeatureRow: View {
    public let feature: WhatsNewFeature

    public init(feature: WhatsNewFeature) {
        self.feature = feature
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(feature.iconColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WhatsNewView(
        appName: "Flowmark",
        features: [
            WhatsNewFeature(
                icon: "sparkles",
                iconColor: .purple,
                title: "Discover New Content",
                description: "Browse trending movies and TV shows powered by Jellyseerr."
            ),
            WhatsNewFeature(
                icon: "pip.fill",
                iconColor: .blue,
                title: "Picture-in-Picture",
                description: "Keep watching while you browse with PiP support."
            ),
            WhatsNewFeature(
                icon: "arrow.down.circle",
                iconColor: .green,
                title: "Download for Offline",
                description: "Save content to watch later without an internet connection."
            )
        ],
        onContinue: {}
    )
}
