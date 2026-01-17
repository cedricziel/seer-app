import SwiftUI
import UIKit

/// In-app feedback form for users to submit bug reports, feature requests, or general feedback
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackType: FeedbackType = .general
    @State private var descriptionText = ""
    @State private var email = ""
    @State private var isSharing = false

    /// Minimum character count for description
    private let minimumDescriptionLength = 10

    /// Device and app information
    private var deviceInfo: DeviceInfo {
        DeviceInfo()
    }

    /// Whether the form is valid for submission
    private var isFormValid: Bool {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumDescriptionLength
    }

    var body: some View {
        Form {
            feedbackTypeSection
            descriptionSection
            contactSection
            deviceInfoSection
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") {
                    shareFeedback()
                }
                .disabled(!isFormValid)
            }
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(items: [formattedFeedback])
        }
    }

    // MARK: - Sections

    private var feedbackTypeSection: some View {
        Section {
            Picker("Type", selection: $feedbackType) {
                ForEach(FeedbackType.allCases) { type in
                    Label(type.rawValue, systemImage: type.iconName)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Feedback Type")
        }
    }

    private var descriptionSection: some View {
        Section {
            TextEditor(text: $descriptionText)
                .frame(minHeight: 120)
                .overlay(alignment: .topLeading) {
                    if descriptionText.isEmpty {
                        Text("Describe your feedback...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
        } header: {
            Text("Description")
        } footer: {
            if descriptionText.count < minimumDescriptionLength {
                Text("Please enter at least \(minimumDescriptionLength) characters")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contactSection: some View {
        Section {
            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        } header: {
            Text("Contact (Optional)")
        } footer: {
            Text("Include your email if you'd like a response")
        }
    }

    private var deviceInfoSection: some View {
        Section {
            LabeledContent("App Version", value: deviceInfo.appVersion)
            LabeledContent("iOS Version", value: deviceInfo.systemVersion)
            LabeledContent("Device", value: deviceInfo.deviceModel)
        } header: {
            Text("Device Information")
        } footer: {
            Text("This information helps us diagnose issues")
        }
    }

    // MARK: - Actions

    private func shareFeedback() {
        isSharing = true
    }

    /// Formatted feedback content for sharing
    private var formattedFeedback: String {
        var content = """
        === Seer Feedback ===

        Type: \(feedbackType.rawValue)

        Description:
        \(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines))

        """

        if !email.isEmpty {
            content += """

            Contact: \(email)

            """
        }

        content += """

        --- Device Info ---
        App Version: \(deviceInfo.appVersion)
        iOS Version: \(deviceInfo.systemVersion)
        Device: \(deviceInfo.deviceModel)
        Locale: \(deviceInfo.locale)
        Timezone: \(deviceInfo.timezone)
        """

        return content
    }
}

// MARK: - Device Info

private struct DeviceInfo {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var systemVersion: String {
        UIDevice.current.systemVersion
    }

    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    var locale: String {
        Locale.current.identifier
    }

    var timezone: String {
        TimeZone.current.identifier
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
