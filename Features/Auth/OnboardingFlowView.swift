import SeerCore
import SeerUI
import SwiftUI

/// Top-level coordinator for the streamlined onboarding flow. Switches
/// between welcome / manual entry / Quick Connect / password sub-views
/// based on `OnboardingViewModel.phase`.
struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @StateObject private var viewModel: OnboardingViewModel

    init(appState: AppState, onboardingManager: OnboardingManager) {
        _viewModel = StateObject(
            wrappedValue: OnboardingViewModel(
                appState: appState,
                onboardingManager: onboardingManager
            )
        )
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(content: toolbarContent)
        }
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .welcome:
            welcomeView
        case .manualEntry:
            manualEntryView
        case let .quickConnect(serverDisplay):
            quickConnectView(serverDisplay: serverDisplay)
        case let .password(serverDisplay):
            passwordView(serverDisplay: serverDisplay)
        case .completing:
            ProgressView("Signing in…")
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if showsBackButton {
                Button("Back") { viewModel.backToWelcome() }
            }
        }
    }

    private var showsBackButton: Bool {
        switch viewModel.phase {
        case .welcome, .completing: false
        default: true
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        let suggestions = viewModel.welcomeSuggestions
        return WelcomeView(
            primarySuggestion: suggestions.primary,
            secondarySuggestions: suggestions.secondary,
            onSelectSuggestion: { viewModel.selectSuggestion($0) },
            onManualEntry: { viewModel.tapManualEntry() }
        )
    }

    // MARK: - Manual entry

    private var manualEntryView: some View {
        ManualServerEntryView(
            url: $viewModel.manualURL,
            isValidating: viewModel.isValidatingManualURL,
            errorMessage: viewModel.manualURLError,
            onContinue: {
                Task { await viewModel.validateManualURLAndAdvance() }
            }
        )
    }

    // MARK: - Quick Connect

    private func quickConnectView(serverDisplay: String) -> some View {
        QuickConnectView(
            code: viewModel.quickConnectCode ?? "------",
            serverHost: serverDisplay,
            isPolling: viewModel.quickConnectIsPolling,
            onUsePassword: { viewModel.switchToPassword() },
            onCancel: { viewModel.cancelQuickConnect() },
            onCopyCode: {
                #if canImport(UIKit) && !os(tvOS)
                    if let code = viewModel.quickConnectCode {
                        UIPasteboard.general.string = code
                    }
                #endif
            }
        )
    }

    // MARK: - Password

    private func passwordView(serverDisplay: String) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Sign in to \(serverDisplay)")
                        .font(.headline)
                    Text("Use your Jellyfin credentials to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Username") {
                TextField("Username", text: $viewModel.passwordUsername)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .modifier(NoAutocapitalizationIfAvailable())
            }

            Section("Password") {
                SecureField("Password", text: $viewModel.passwordPassword)
                    .textContentType(.password)
            }

            if let error = viewModel.passwordError {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(error)
                            .font(.subheadline)
                    }
                }
            }

            Section {
                Button {
                    Task { await viewModel.submitPassword() }
                } label: {
                    HStack {
                        if viewModel.isAuthenticating {
                            ProgressView()
                        }
                        Text(viewModel.isAuthenticating ? "Signing in…" : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.passwordUsername.isEmpty || viewModel.isAuthenticating)
            }

            Section {
                Button("Try Quick Connect Instead") {
                    Task { await viewModel.switchToQuickConnect() }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Sign In")
        .modifier(InlineNavigationTitleIfAvailable())
    }
}

// MARK: - Cross-platform shims

private struct NoAutocapitalizationIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content.textInputAutocapitalization(.never)
        #else
            content
        #endif
    }
}

private struct InlineNavigationTitleIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content.navigationBarTitleDisplayMode(.inline)
        #else
            content
        #endif
    }
}
