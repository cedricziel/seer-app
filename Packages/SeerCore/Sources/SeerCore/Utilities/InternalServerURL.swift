import Foundation

public enum InternalServerURL {
    /// Returns nil for blank input or an HTTP/HTTPS server URL. Throws actionable advice for invalid input.
    public static func parse(_ input: String) throws -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw ValidationError.unsupportedURL
        }
        guard let host = url.host, !host.isEmpty else {
            throw ValidationError.missingHost
        }
        return url
    }

    private enum ValidationError: String, LocalizedError {
        case unsupportedURL = "Use http:// or https://, for example http://192.168.1.10:8096."
        case missingHost = "Include a host, for example http://192.168.1.10:8096."

        var errorDescription: String? {
            rawValue
        }
    }
}
