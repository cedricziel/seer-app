import Foundation

/// Categories for user feedback submissions
enum FeedbackType: String, CaseIterable, Identifiable {
    case bug = "Bug Report"
    case feature = "Feature Request"
    case general = "General Feedback"

    var id: String { rawValue }

    /// System image name for the feedback type
    var iconName: String {
        switch self {
        case .bug:
            "ladybug"
        case .feature:
            "lightbulb"
        case .general:
            "bubble.left"
        }
    }

    /// Description of what this feedback type is for
    var description: String {
        switch self {
        case .bug:
            "Report an issue or unexpected behavior"
        case .feature:
            "Suggest a new feature or improvement"
        case .general:
            "Share general thoughts or comments"
        }
    }
}
