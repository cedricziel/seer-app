import SwiftUI

extension View {
    func downloadErrorAlert(_ feedback: DownloadActionFeedback) -> some View {
        alert("Download Failed", isPresented: Binding(
            get: { feedback.message != nil },
            set: { if !$0 { feedback.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(feedback.message ?? "Please try again.")
        }
    }
}
