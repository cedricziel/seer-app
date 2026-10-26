import JellyseerrClient
import SwiftUI

extension SearchViewModel: RequestOptionsProvider {}

struct RequestOptionsSheet: View {
    let result: SearchResult
    @ObservedObject var viewModel: SearchViewModel
    var canRequest4K: Bool
    let onSubmit: ([Int]?, Bool) -> Void

    var body: some View {
        SharedRequestOptionsSheet(
            result: result,
            provider: viewModel,
            canRequest4K: canRequest4K,
            onSubmit: onSubmit
        )
    }
}
