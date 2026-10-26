import SwiftUI

public extension View {
    /// Presents a player in a resizable Mac sheet or a full-screen mobile presentation.
    /// - Parameter onDismiss: Called when the platform presentation finishes dismissing.
    func playerCover(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        #if os(macOS)
            sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
            fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    /// Presents the selected item using the platform's player presentation.
    func playerCover<Item: Identifiable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        #if os(macOS)
            sheet(item: item, content: content)
        #else
            fullScreenCover(item: item, content: content)
        #endif
    }
}
