//
//  Resource.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation

/// Represents a single HTTP or WebSocket request configuration.
///
/// A `Resource` encapsulates all information needed to construct a network request.
/// It supports:
/// - JSON-based HTTP requests (Encodable body)
/// - Multipart/form-data HTTP requests
/// - Plain HTTP requests without a body
/// - WebSocket requests (with optional `ws` or `wss` scheme override)
struct Resource: Sendable {
    enum WebSocketScheme: String {
        case wss
        case ws
    }
    
    /// An optional `Encodable & Sendable` body for JSON-based HTTP requests.
    var request: (Encodable & Sendable)?
    
    /// Optional binary content for multipart/form-data HTTP requests.
    var multipartData: Data?
    
    /// The HTTP method (GET, POST, PUT, DELETE, etc.).
    let method: HTTPMethod
    
    /// HTTP headers to include in the request.
    var headers: HeaderFields = [:]
    
    /// The API endpoint path or URL.
    var endpoint: Endpoint
    
    /// Optional WebSocket scheme override (`ws` or `wss`).
    /// If provided, this will replace the base URL's scheme when constructing the final URL.
    var webSocketScheme: WebSocketScheme?
    
    /// Optional query parameters to append to the URL.
    var query: [URLQueryItem]?
    
    // MARK: - Initializers
    
    /// Creates a JSON-based HTTP request.
    ///
    /// - Parameters:
    ///   - request: The body object conforming to `Encodable & Sendable`.
    ///   - method: The HTTP method.
    ///   - headers: HTTP headers to include.
    ///   - endpoint: The API endpoint.
    init(
        request: Encodable & Sendable,
        method: HTTPMethod,
        headers: HeaderFields,
        endpoint: Endpoint
    ) {
        self.request = request
        self.method = method
        self.headers = headers
        self.endpoint = endpoint
    }
    
    /// Creates a multipart/form-data HTTP request.
    ///
    /// - Parameters:
    ///   - multipartData: Binary form-data content.
    ///   - method: The HTTP method.
    ///   - headers: HTTP headers to include.
    ///   - endpoint: The API endpoint.
    init(
        multipartData: Data,
        method: HTTPMethod,
        headers: HeaderFields,
        endpoint: Endpoint
    ) {
        self.multipartData = multipartData
        self.method = method
        self.headers = headers
        self.endpoint = endpoint
    }
    
    /// Creates an HTTP request without a body (e.g., GET, DELETE).
    ///
    /// - Parameters:
    ///   - method: The HTTP method.
    ///   - headers: HTTP headers to include.
    ///   - endpoint: The API endpoint.
    init(
        method: HTTPMethod,
        headers: HeaderFields,
        endpoint: Endpoint
    ) {
        self.method = method
        self.headers = headers
        self.endpoint = endpoint
    }
    
    /// Creates a WebSocket resource.
    ///
    /// - Parameters:
    ///   - encrypted: If `true`, uses `wss` (secure WebSocket). Otherwise uses `ws`.
    ///   - headers: Optional HTTP headers to include in the initial handshake.
    ///   - endpoint: The WebSocket endpoint.
    init(
        encrypted: Bool,
        headers: HeaderFields,
        endpoint: Endpoint
    ) {
        self.method = .get
        self.webSocketScheme = WebSocketScheme(rawValue: encrypted ? "wss" : "ws")
        self.headers = headers
        self.endpoint = endpoint
    }
}

extension Resource {
    /// Constructs a fully-qualified URL for this resource.
    ///
    /// - Parameter baseUrl: The base URL of the API.
    /// - Returns: The complete `URL` including the endpoint path and query parameters.
    ///
    /// - Note: If `webSocketScheme` is set, it overrides the base URL scheme (`http/https`) with `ws/wss`.
    /// - Precondition: Fails if the URL components cannot be assembled into a valid `URL`.
    func buildEndpointUrl(_ baseUrl: URL) -> URL {
        var components = URLComponents(string: baseUrl.absoluteString)
        
        if let webSocketScheme {
            components?.scheme = webSocketScheme.rawValue
        }
        
        components?.path = endpoint.path
        
        if let query = query {
            components?.queryItems = query
        }
        
        guard let url = components?.url else {
            preconditionFailure("Invalid URL components for \(endpoint.path)")
        }
        
        return url
    }
    
    /// Builds the final set of headers for the request by merging
    /// the endpoint's default headers with this resource's additional headers.
    ///
    /// - Note: Values in `self.headers` take precedence over duplicates in `endpoint.headers`.
    func buildHeaderFields() -> HeaderFields {
        return endpoint.headers.merging(headers) { _, current in current }
    }
}
