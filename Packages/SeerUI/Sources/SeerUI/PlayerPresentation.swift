import SwiftUI

public extension View {
    /// Presents a player in a resizable Mac sheet or a full-screen mobile presentation.
    func playerCover(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        #if os(macOS)
            sheet(isPresented: isPresented, content: content)
        #else
            fullScreenCover(isPresented: isPresented, content: content)
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
