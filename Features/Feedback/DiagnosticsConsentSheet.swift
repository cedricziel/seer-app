import SeerCore
import SwiftUI

/// First-time consent prompt for diagnostics data collection.
/// Shown to users who haven't yet made a choice about sharing diagnostic data.
struct DiagnosticsConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var consent = DiagnosticsConsent.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    benefitsSection
                    dataInfoSection
                    privacyAssuranceSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Help Improve Seer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        consent.disableAllDiagnostics()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding()
                .background(
                    Circle()
                        .fill(.tint.opacity(0.1))
                )

            Text("Share Diagnostics?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Help us make Seer better by sharing anonymous crash reports and performance data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenefitRow(
                icon: "ladybug.fill",
                iconColor: .red,
                title: "Fix Crashes Faster",
                description: "We'll know when something breaks and can fix it quickly"
            )

            BenefitRow(
                icon: "hare.fill",
                iconColor: .orange,
                title: "Improve Performance",
                description: "Identify slow screens and optimize them"
            )

            BenefitRow(
                icon: "star.fill",
                iconColor: .yellow,
                title: "Better Experience",
                description: "Prioritize improvements that matter most"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
        )
    }

    private var dataInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What we collect:")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 4) {
                DataPointRow(text: "Crash stack traces")
                DataPointRow(text: "App launch & hang times")
                DataPointRow(text: "Memory & CPU usage")
                DataPointRow(text: "Device model & iOS version")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyAssuranceSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)

            Text("Data is anonymous, never sold, and you can change this anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.green.opacity(0.1))
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                consent.enableAllDiagnostics()
                dismiss()
            } label: {
                Text("Share Diagnostics")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                consent.disableAllDiagnostics()
                dismiss()
            } label: {
                Text("Don't Share")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://seer.app/privacy")!) {
                Text("Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
    }
}

// MARK: - Helper Views

private struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)

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

private struct DataPointRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
            Text(text)
        }
    }
}

#Preview {
    DiagnosticsConsentSheet()
}
