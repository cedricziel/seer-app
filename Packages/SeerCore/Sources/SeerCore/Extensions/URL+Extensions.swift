import Foundation

public extension URL {
    /// Appends path components to the URL
    func appendingPathComponents(_ components: String...) -> URL {
        var url = self
        for component in components {
            url = url.appendingPathComponent(component)
        }
        return url
    }

    /// Returns a URL with query items added
    func withQueryItems(_ items: [String: String]) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        for (key, value) in items {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems

        return components.url
    }

    /// Returns URLComponents from this URL, throwing if conversion fails
    func urlComponents(resolvingAgainstBaseURL: Bool = false) throws -> URLComponents {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: resolvingAgainstBaseURL) else {
            throw URLError(.badURL)
        }
        return components
    }
}
