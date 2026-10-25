import Foundation

/// UserDefaults supports concurrent access from UI and exporter queues.
final class DiagnosticsPreferences: @unchecked Sendable {
    static let shared = DiagnosticsPreferences(defaults: .standard)
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var crashReportsEnabled: Bool {
        get { enabled("diagnostics.crashReportsEnabled") }
        set { defaults.set(newValue, forKey: "diagnostics.crashReportsEnabled") }
    }

    var performanceMetricsEnabled: Bool {
        get { enabled("diagnostics.performanceMetricsEnabled") }
        set { defaults.set(newValue, forKey: "diagnostics.performanceMetricsEnabled") }
    }

    private func enabled(_ key: String) -> Bool {
        if let value = defaults.object(forKey: key) as? Bool {
            return value
        }
        // Older declines could leave a category unset. Preserve that choice.
        return !defaults.bool(forKey: "diagnostics.hasShownConsentPrompt")
    }
}
