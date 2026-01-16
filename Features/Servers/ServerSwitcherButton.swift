import SeerCore
import SeerUI
import SwiftUI

/// Toolbar button showing current server's avatar that opens the server switcher
struct ServerSwitcherButton: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingSwitcher = false

    var body: some View {
        Button {
            showingSwitcher = true
        } label: {
            HStack(spacing: 4) {
                ServerAvatar(
                    emoji: appState.activeServer?.emoji ?? "🖥️",
                    size: 28
                )
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingSwitcher) {
            ServerSwitcherView()
        }
    }
}

#Preview {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ServerSwitcherButton()
                }
            }
    }
    .environmentObject(AppState())
}
