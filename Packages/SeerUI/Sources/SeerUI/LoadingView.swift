import SwiftUI

/// A view that displays a loading indicator
public struct LoadingView: View {
    public let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// A view that displays an error with a retry button
public struct ErrorView: View {
    public let error: String
    public let retryAction: (() -> Void)?

    public init(error: String, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let retryAction {
                Button(action: retryAction) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Double tap to try again")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error)")
    }
}

/// A view that displays when there's no content
public struct EmptyContentView: View {
    public let title: String
    public let systemImage: String
    public let description: String?

    public init(title: String, systemImage: String, description: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description {
                Text(description)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(emptyContentAccessibilityLabel)
    }

    private var emptyContentAccessibilityLabel: String {
        if let description {
            "\(title). \(description)"
        } else {
            title
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingView(message: "Loading...")
            .frame(height: 200)

        ErrorView(error: "Something went wrong") {
            print("Retry tapped")
        }
        .frame(height: 200)

        EmptyContentView(
            title: "No Results",
            systemImage: "magnifyingglass",
            description: "Try searching for something else"
        )
        .frame(height: 200)
    }
}
