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

        // Detect scheme via string prefix rather than URL.scheme — Foundation
        // on Linux parses bare "host:port" as a custom scheme, which would
        // otherwise hide the missing-prefix case from users.
        let lower = trimmed.lowercased()
        let hasHTTP = lower.hasPrefix("http://") || lower.hasPrefix("https://")
        if !hasHTTP {
            return AuthErrorAdvice(
                message: "Missing http:// or https:// prefix",
                suggestion: "Try \"https://\(trimmed)\" or \"http://\(trimmed)\" for a local server"
            )
        }

        guard let url = URL(string: trimmed) else {
            return AuthErrorAdvice(
                message: "That doesn't look like a valid URL",
                suggestion: "Check for typos and include the scheme, e.g. https://your-server.com"
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
        // Apple's `as? URLError` already bridges from NSError when the
        // domain is NSURLErrorDomain, so an explicit NSError fallback
        // isn't necessary (and is awkward to write portably because
        // URLError.Code's failable/non-failable init differs across
        // Apple's Foundation and swift-corelibs-foundation).
        if let urlError = error as? URLError {
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
            AuthErrorAdvice(
                message: "Couldn't find that server",
                suggestion: "Check the address for typos. For local servers try the IP, e.g. 192.168.1.10:8096"
            )
        case .cannotConnectToHost:
            AuthErrorAdvice(
                message: "Can't reach the server",
                suggestion: portSuggestion(for: urlString) ?? "Verify the port and that the server is running"
            )
        case .timedOut:
            AuthErrorAdvice(
                message: "Connection timed out",
                suggestion: "Check the server is online and reachable from this network"
            )
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            AuthErrorAdvice(
                message: "Couldn't establish a secure connection",
                suggestion: "If your server uses a self-signed certificate, try http:// for testing"
            )
        case .appTransportSecurityRequiresSecureConnection:
            AuthErrorAdvice(
                message: "Insecure connections aren't allowed by default",
                suggestion: "Use https:// or configure App Transport Security for this domain"
            )
        case .notConnectedToInternet, .networkConnectionLost:
            AuthErrorAdvice(
                message: "No internet connection",
                suggestion: "Reconnect to Wi-Fi or cellular and try again"
            )
        case .userAuthenticationRequired:
            AuthErrorAdvice(
                message: "The server rejected the credentials",
                suggestion: "Double-check your username and password"
            )
        default:
            AuthErrorAdvice(
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
            isPrivate172(host) ||
            host == "localhost" ||
            host.hasSuffix(".local")

        if isLikelyLocal {
            return "Try adding the Jellyfin port, e.g. \(host):8096"
        }
        return "Verify the port and that the server is running"
    }

    /// RFC 1918 limits the 172.x private range to 172.16.0.0–172.31.255.255.
    /// `host.hasPrefix("172.")` would misclassify the public 172.0–172.15
    /// and 172.32–172.255 blocks (now ARIN-allocated) as local.
    private static func isPrivate172(_ host: String) -> Bool {
        let parts = host.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2,
              parts[0] == "172",
              let octet = Int(parts[1])
        else {
            return false
        }
        return (16 ... 31).contains(octet)
    }
}
