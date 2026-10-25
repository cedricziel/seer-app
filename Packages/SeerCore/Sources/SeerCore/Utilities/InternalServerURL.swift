import Foundation

public enum InternalServerURL {
    /// Returns nil for blank input or an HTTP/HTTPS server URL. Throws actionable advice for invalid input.
    public static func parse(_ input: String) throws -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let advice = AuthErrorFormatter.validate(urlString: trimmed) {
            throw ValidationError(advice: advice)
        }
        guard let url = URL(string: trimmed) else {
            throw ValidationError(advice: AuthErrorAdvice(message: "Enter a valid HTTP or HTTPS server URL."))
        }
        return url
    }

    private struct ValidationError: LocalizedError {
        let advice: AuthErrorAdvice

        var errorDescription: String? {
            [advice.message, advice.suggestion].compactMap(\.self).joined(separator: ". ")
        }
    }
}
