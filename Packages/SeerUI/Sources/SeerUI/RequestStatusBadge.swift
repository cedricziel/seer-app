import SwiftUI

/// A badge showing the status of a media request
public struct RequestStatusBadge: View {
    public enum Status: Sendable {
        case available
        case pending
        case approved
        case declined
        case processing
        case notRequested

        public var label: String {
            switch self {
            case .available: "Available"
            case .pending: "Pending"
            case .approved: "Approved"
            case .declined: "Declined"
            case .processing: "Processing"
            case .notRequested: "Not Requested"
            }
        }

        public var iconName: String {
            switch self {
            case .available: "checkmark.seal.fill"
            case .pending: "clock"
            case .approved: "checkmark.circle"
            case .declined: "xmark.circle"
            case .processing: "arrow.triangle.2.circlepath"
            case .notRequested: "plus.circle"
            }
        }

        public var color: Color {
            switch self {
            case .available: .green
            case .pending: .orange
            case .approved: .blue
            case .declined: .red
            case .processing: .purple
            case .notRequested: .secondary
            }
        }
    }

    public let status: Status
    public let style: Style

    public enum Style {
        case compact
        case full
    }

    public init(status: Status, style: Style = .compact) {
        self.status = status
        self.style = style
    }

    public var body: some View {
        switch style {
        case .compact:
            compactBadge
        case .full:
            fullBadge
        }
    }

    private var compactBadge: some View {
        Image(systemName: status.iconName)
            .font(.caption)
            .foregroundStyle(status.color)
    }

    private var fullBadge: some View {
        Label(status.label, systemImage: status.iconName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .clipShape(Capsule())
    }
}

/// A badge showing media type (Movie/TV)
public struct MediaTypeBadge: View {
    public enum MediaType: String, Sendable {
        case movie = "Movie"
        case tv = "TV Show"
    }

    public let type: MediaType

    public init(type: MediaType) {
        self.type = type
    }

    public var body: some View {
        Text(type.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(type == .movie ? Color.blue : Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            RequestStatusBadge(status: .available, style: .compact)
            RequestStatusBadge(status: .pending, style: .compact)
            RequestStatusBadge(status: .approved, style: .compact)
            RequestStatusBadge(status: .declined, style: .compact)
            RequestStatusBadge(status: .processing, style: .compact)
        }

        VStack(spacing: 8) {
            RequestStatusBadge(status: .available, style: .full)
            RequestStatusBadge(status: .pending, style: .full)
            RequestStatusBadge(status: .approved, style: .full)
            RequestStatusBadge(status: .declined, style: .full)
            RequestStatusBadge(status: .processing, style: .full)
        }

        HStack {
            MediaTypeBadge(type: .movie)
            MediaTypeBadge(type: .tv)
        }
    }
    .padding()
}
