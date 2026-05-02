#if os(iOS)
    import AVKit
    import SwiftUI
    import UIKit

    /// SwiftUI wrapper around `AVRoutePickerView` that surfaces the system
    /// AirPlay route-selection sheet. Video-capable receivers are listed first.
    struct AirPlayRouteButton: UIViewRepresentable {
        func makeUIView(context _: Context) -> AVRoutePickerView {
            let picker = AVRoutePickerView()
            picker.prioritizesVideoDevices = true
            picker.activeTintColor = .systemBlue
            picker.tintColor = .white
            picker.backgroundColor = .clear
            return picker
        }

        func updateUIView(_: AVRoutePickerView, context _: Context) {}
    }
#endif
