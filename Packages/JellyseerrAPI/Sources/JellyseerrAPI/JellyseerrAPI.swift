// JellyseerrAPI - Generated OpenAPI Client
//
// This module provides a Swift client generated from the Jellyseerr OpenAPI specification.
// The code is generated at build time by swift-openapi-generator.

import Foundation
import HTTPTypes
@_exported import OpenAPIRuntime
@_exported import OpenAPIURLSession

// MARK: - API Key Middleware

/// Middleware that adds API key authentication to requests.
public struct APIKeyMiddleware: ClientMiddleware {
    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name("X-Api-Key")!] = apiKey
        return try await next(request, body, baseURL)
    }
}

// MARK: - Cookie Authentication Middleware

/// Middleware that handles cookie-based authentication.
public struct CookieAuthMiddleware: ClientMiddleware {
    private let cookie: String

    public init(cookie: String) {
        self.cookie = cookie
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.cookie] = cookie
        return try await next(request, body, baseURL)
    }
}
