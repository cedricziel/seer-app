import SwiftUI

/// A circular avatar displaying a server's emoji identifier
public struct ServerAvatar: View {
    public let emoji: String
    public var size: CGFloat = 32
    public var backgroundColor: Color = .secondary.opacity(0.2)

    public init(emoji: String, size: CGFloat = 32, backgroundColor: Color = .secondary.opacity(0.2)) {
        self.emoji = emoji
        self.size = size
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(backgroundColor)
            .clipShape(Circle())
    }
}

/// A grid of common server emoji options for selection
public struct ServerEmojiPicker: View {
    @Binding public var selectedEmoji: String
    @Binding public var isExpanded: Bool

    public static let commonEmojis = ["🏠", "💼", "☁️", "🖥️", "📺", "🎬", "🎮", "🌐", "⚡", "🔒"]

    public init(selectedEmoji: Binding<String>, isExpanded: Binding<Bool>) {
        _selectedEmoji = selectedEmoji
        _isExpanded = isExpanded
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
            ForEach(Self.commonEmojis, id: \.self) { emoji in
                Button {
                    selectedEmoji = emoji
                    isExpanded = false
                } label: {
                    Text(emoji)
                        .font(.title)
                        .frame(width: 44, height: 44)
                        .background(emoji == selectedEmoji ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// A server row item showing avatar, name, and connection status
public struct ServerRowView: View {
    public let name: String
    public let emoji: String
    public let jellyfinHost: String
    public let jellyseerrHost: String?
    public let isActive: Bool

    public init(
        name: String,
        emoji: String,
        jellyfinHost: String,
        jellyseerrHost: String? = nil,
        isActive: Bool = false
    ) {
        self.name = name
        self.emoji = emoji
        self.jellyfinHost = jellyfinHost
        self.jellyseerrHost = jellyseerrHost
        self.isActive = isActive
    }

    public var body: some View {
        HStack(spacing: 12) {
            ServerAvatar(emoji: emoji, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(jellyfinHost)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let jellyseerrHost {
                    HStack(spacing: 4) {
                        Text("+")
                        Text(jellyseerrHost)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        ServerAvatar(emoji: "🏠", size: 32)
        ServerAvatar(emoji: "💼", size: 44)
        ServerAvatar(emoji: "☁️", size: 56)

        Divider()

        ServerRowView(
            name: "Home Server",
            emoji: "🏠",
            jellyfinHost: "jellyfin.home.local",
            jellyseerrHost: "jellyseerr.home.local",
            isActive: true
        )

        ServerRowView(
            name: "Work Media",
            emoji: "💼",
            jellyfinHost: "media.work.com",
            jellyseerrHost: nil,
            isActive: false
        )
    }
    .padding()
}
