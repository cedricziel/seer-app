import Foundation

/// Response from Jellyfin authentication endpoint
public struct AuthResponse: Codable, Sendable {
    public let user: User
    public let accessToken: String
    public let serverId: String

    public struct User: Codable, Sendable {
        public let id: String
        public let name: String
        public let serverID: String?
        public let hasPassword: Bool?
        public let hasConfiguredPassword: Bool?
        public let hasConfiguredEasyPassword: Bool?

        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case name = "Name"
            case serverID = "ServerId"
            case hasPassword = "HasPassword"
            case hasConfiguredPassword = "HasConfiguredPassword"
            case hasConfiguredEasyPassword = "HasConfiguredEasyPassword"
        }
    }

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}
