import Foundation
import SwiftUI

/// Manages onboarding state and What's New presentation
@MainActor
final class OnboardingManager: ObservableObject {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    @AppStorage("isFirstLaunchAfterSetup") private(set) var isFirstLaunchAfterSetup = false

    @Published var showWhatsNew = false

    var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var shouldShowWhatsNew: Bool {
        hasCompletedOnboarding && lastSeenWhatsNewVersion != currentAppVersion
    }

    /// Marks initial onboarding (server setup) as complete
    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        isFirstLaunchAfterSetup = true
        // Set current version so new users don't see What's New immediately
        lastSeenWhatsNewVersion = currentAppVersion
    }

    /// Marks What's New as seen for current version
    func markWhatsNewSeen() {
        lastSeenWhatsNewVersion = currentAppVersion
        isFirstLaunchAfterSetup = false
    }

    /// Checks if What's New should be shown and triggers display
    func checkAndShowWhatsNew() {
        if shouldShowWhatsNew {
            showWhatsNew = true
        }
    }

    /// Clears the first launch flag (call after user has seen first-time tips)
    func clearFirstLaunchFlag() {
        isFirstLaunchAfterSetup = false
    }
}
