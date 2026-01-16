import SwiftUI

/// An inline empty state view for sections (not full-page)
public struct SectionEmptyView: View {
    public let message: String
    public let systemImage: String

    public init(message: String, systemImage: String) {
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        SectionEmptyView(message: "No recent additions", systemImage: "film.stack")
        SectionEmptyView(message: "Nothing to continue", systemImage: "play.circle")
    }
}
