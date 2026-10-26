import SwiftUI

extension View {
    func downloadErrorAlert(_ feedback: DownloadActionFeedback, isActive: Bool = true) -> some View {
        alert("Download Failed", isPresented: Binding(
            get: { isActive && feedback.message != nil },
            set: { if !$0 { feedback.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(feedback.message ?? "Please try again.")
        }
    }
}
