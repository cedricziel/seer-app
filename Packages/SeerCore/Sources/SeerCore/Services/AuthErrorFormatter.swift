import Foundation

/// Translates raw connection errors and malformed URLs into actionable
/// guidance for the auth setup flow.
///
/// The result has a primary `message` (what went wrong) and an optional
/// `suggestion` (what the user can try). UI surfaces both lines.
public struct AuthErrorAdvice: Equatable, Sendable {
    public let message: String
    public let suggestion: String?

    public init(message: String, suggestion: String? = nil) {
        self.message = message
        self.suggestion = suggestion
    }
}

public enum AuthErrorFormatter {
    /// Inspects a user-supplied URL string and returns advice if it's clearly
    /// malformed. Returns `nil` if the URL looks acceptable.
    ///
    /// This runs before any network call, so users see scheme/port mistakes
    /// immediately instead of waiting for a timeout.
    public static func validate(urlString: String) -> AuthErrorAdvice? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return AuthErrorAdvice(
                message: "Please enter a server URL",
                suggestion: "Example: https://jellyfin.example.com or http://192.168.1.10:8096"
            )
        }

        guard let url = URL(string: trimmed) else {
            return AuthErrorAdvice(
                message: "That doesn't look like a valid URL",
                suggestion: "Check for typos and include the scheme, e.g. https://your-server.com"
            )
        }

        let scheme = url.scheme?.lowercased()
        if scheme == nil || (scheme != "http" && scheme != "https") {
            return AuthErrorAdvice(
                message: "Missing http:// or https:// prefix",
                suggestion: "Try \"https://\(trimmed)\" or \"http://\(trimmed)\" for a local server"
            )
        }

        if url.host?.isEmpty ?? true {
            return AuthErrorAdvice(
                message: "URL is missing a host name",
                suggestion: "Include the server address, e.g. https://jellyfin.example.com"
            )
        }

        return nil
    }

    /// Maps a thrown error into actionable advice. Falls back to the
    /// localized description when no specific suggestion fits.
    public static func advice(for error: Error, urlString: String? = nil) -> AuthErrorAdvice {
        if let urlError = error as? URLError {
            return advice(for: urlError, urlString: urlString)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let urlError = URLError(URLError.Code(rawValue: nsError.code))
            return advice(for: urlError, urlString: urlString)
        }

        return AuthErrorAdvice(
            message: error.localizedDescription,
            suggestion: nil
        )
    }

    private static func advice(for error: URLError, urlString: String?) -> AuthErrorAdvice {
        switch error.code {
        case .cannotFindHost, .dnsLookupFailed:
            return AuthErrorAdvice(
                message: "Couldn't find that server",
                suggestion: "Check the address for typos. For local servers try the IP, e.g. 192.168.1.10:8096"
            )
        case .cannotConnectToHost:
            return AuthErrorAdvice(
                message: "Can't reach the server",
                suggestion: portSuggestion(for: urlString) ?? "Verify the port and that the server is running"
            )
        case .timedOut:
            return AuthErrorAdvice(
                message: "Connection timed out",
                suggestion: "Check the server is online and reachable from this network"
            )
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            return AuthErrorAdvice(
                message: "Couldn't establish a secure connection",
                suggestion: "If your server uses a self-signed certificate, try http:// for testing"
            )
        case .appTransportSecurityRequiresSecureConnection:
            return AuthErrorAdvice(
                message: "Insecure connections aren't allowed by default",
                suggestion: "Use https:// or configure App Transport Security for this domain"
            )
        case .notConnectedToInternet, .networkConnectionLost:
            return AuthErrorAdvice(
                message: "No internet connection",
                suggestion: "Reconnect to Wi-Fi or cellular and try again"
            )
        case .userAuthenticationRequired:
            return AuthErrorAdvice(
                message: "The server rejected the credentials",
                suggestion: "Double-check your username and password"
            )
        default:
            return AuthErrorAdvice(
                message: error.localizedDescription,
                suggestion: nil
            )
        }
    }

    /// If the URL has no port and points at a host, suggest the default
    /// Jellyfin port. This catches the common "I forgot :8096" mistake.
    private static func portSuggestion(for urlString: String?) -> String? {
        guard let urlString,
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.port == nil,
              let host = url.host,
              !host.isEmpty
        else {
            return nil
        }

        let isLikelyLocal = host.hasPrefix("192.168.") ||
            host.hasPrefix("10.") ||
            host.hasPrefix("172.") ||
            host == "localhost" ||
            host.hasSuffix(".local")

        if isLikelyLocal {
            return "Try adding the Jellyfin port, e.g. \(host):8096"
        }
        return "Verify the port and that the server is running"
    }
}
