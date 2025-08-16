//
//  Resource.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation

/// Represents a single HTTP request configuration
struct Resource: Sendable {
    /// An optional Encodable & Sendable request body for JSON-based requests
    var request: (Encodable & Sendable)?
    
    /// Optional binary data for multipart/form-data requests
    var multipartData: Data?
    
    /// The HTTP method (GET, POST, PUT, DELETE, etc.)
    let method: HTTPMethod
    
    /// HTTP headers to include in the request
    var headers: HeaderFields = [:]
    
    /// The API endpoint path or URL
    var endpoint: Endpoint
    
    /// Optional query parameters to append to the URL
    var query: [URLQueryItem]?
    
    /// Creates a JSON-based request
    /// - Parameters:
    ///   - request: The body object conforming to Encodable & Sendable
    ///   - method: The HTTP method
    ///   - headers: HTTP headers to include
    ///   - endpoint: The API endpoint
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
    
    /// Creates a multipart/form-data request
    /// - Parameters:
    ///   - multipartData: Binary form-data content
    ///   - method: The HTTP method
    ///   - headers: HTTP headers to include
    ///   - endpoint: The API endpoint
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
    
    /// Creates a request without a body (e.g., GET, DELETE)
    /// - Parameters:
    ///   - method: The HTTP method
    ///   - headers: HTTP headers to include
    ///   - endpoint: The API endpoint
    init(
        method: HTTPMethod,
        headers: HeaderFields,
        endpoint: Endpoint
    ) {
        self.method = method
        self.headers = headers
        self.endpoint = endpoint
    }
}

extension Resource {
    /// Constructs a fully-qualified URL for this resource.
    ///
    /// - Parameter baseUrl: The base URL of the API.
    /// - Returns: The complete URL including the endpoint path and query parameters.
    /// - Precondition: Fails if the URL components cannot be assembled into a valid `URL`.
    func buildEndpointUrl(_ baseUrl: URL) -> URL {
        var components = URLComponents(string: baseUrl.absoluteString)
        components?.path = endpoint.path
        
        if let query = query {
            components?.queryItems = query
        }
        
        guard let url = components?.url else {
            preconditionFailure("Invalid URL components for \(endpoint.path)")
        }
        
        return url
    }
    
    /// Builds the final set of headers for the request by merging the endpoint's default headers
    /// with the resource's additional headers.
    ///
    /// - Note: Values in the resource's `headers` take precedence over duplicates in `endpoint.headers`.
    func buildHeaderFields() -> HeaderFields {
        return endpoint.headers.merging(headers) { _ , current in current }
    }
}
