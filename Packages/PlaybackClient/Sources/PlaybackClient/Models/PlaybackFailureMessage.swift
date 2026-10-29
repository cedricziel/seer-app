import Foundation

/// Recovery guidance for playback failures without exposing server error details.
public enum PlaybackFailureMessage {
    public static func message(for error: Error?) -> String {
        var current = error
        for _ in 0 ..< 8 {
            guard let currentError = current else { break }
            if let serviceError = currentError as? PlaybackService.PlaybackError {
                switch serviceError {
                case let .networkError(underlying):
                    current = underlying
                    continue
                case .serverError(401, _):
                    return authenticationMessage
                case .serverError(403, _):
                    return "Your server denied playback access. Ask your server administrator to check your account permissions."
                default:
                    break
                }
            }
            let failure = currentError as NSError
            if failure.domain == NSURLErrorDomain {
                switch failure.code {
                case NSURLErrorUserAuthenticationRequired, NSURLErrorUserCancelledAuthentication:
                    return authenticationMessage
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                     NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorTimedOut:
                    return """
                    The video could not load from your server. \
                    Check your network connection and that your server is available, then retry.
                    """
                default:
                    break
                }
            }
            current = failure.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return """
        This video could not be played. Retry, or close the player and try another title. \
        If this continues, ask your server administrator to check the media and transcoding settings.
        """
    }

    private static let authenticationMessage = """
    The server requires authentication to play this video. \
    Close the player and sign in to your server again. \
    If this continues, ask your server administrator to check playback access.
    """
}
