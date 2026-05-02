import SeerCore
import SwiftUI

/// Settings view for managing privacy and diagnostics preferences
struct PrivacySettingsView: View {
    @StateObject private var consent = DiagnosticsConsent.shared
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            diagnosticsSection
            spotlightIndexSection
            dataCollectionInfoSection
            privacyLinksSection
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var spotlightIndexSection: some View {
        Section {
            Toggle(isOn: $appState.appIntentsIndexingEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Index for Spotlight & Siri")
                        Text("Surface library titles in system search and voice shortcuts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.purple)
                }
            }
        } header: {
            Text("App Intents")
        } footer: {
            Text(
                "When enabled, Spotlight semantically indexes the title, year, and "
                    + "type of items in your library — not posters, descriptions, or "
                    + "watched state. Applies only to this device; not synced via iCloud."
            )
        }
    }

    // MARK: - Sections

    private var diagnosticsSection: some View {
        Section {
            Toggle(isOn: $consent.crashReportsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Crash Reports")
                        Text("Help us fix bugs by sharing crash data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "ladybug")
                        .foregroundStyle(.red)
                }
            }

            Toggle(isOn: $consent.performanceMetricsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Performance Data")
                        Text("Help us improve app speed and responsiveness")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Diagnostic data is anonymized and never sold to third parties. It helps us identify and fix issues.")
        }
    }

    private var dataCollectionInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                DataCollectionRow(
                    icon: "exclamationmark.triangle",
                    iconColor: .orange,
                    title: "Crash Data",
                    description: "Stack traces, device model, OS version"
                )

                DataCollectionRow(
                    icon: "speedometer",
                    iconColor: .blue,
                    title: "Performance Data",
                    description: "Launch time, memory usage, hang reports"
                )

                DataCollectionRow(
                    icon: "iphone",
                    iconColor: .gray,
                    title: "Device Info",
                    description: "Model identifier, iOS version, locale"
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("What We Collect")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Label("Not linked to your identity", systemImage: "person.slash")
                Label("Not used for tracking", systemImage: "hand.raised.slash")
                Label("Not shared with advertisers", systemImage: "megaphone.slash")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
    }

    private var privacyLinksSection: some View {
        Section {
            Link(destination: URL(string: "https://seer.app/privacy")!) {
                Label("Privacy Policy", systemImage: "doc.text")
            }

            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: settingsURL) {
                    Label("System Privacy Settings", systemImage: "gear")
                }
            }
        } header: {
            Text("More Information")
        }
    }
}

// MARK: - Data Collection Row

private struct DataCollectionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
