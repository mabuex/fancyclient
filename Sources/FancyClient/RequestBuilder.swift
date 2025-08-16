//
//  RequestBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation

/// A type-safe, chainable builder for constructing HTTP requests (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`)
/// targeting a given `Endpoint`.
///
/// `RequestBuilder` acts as the entry point for creating requests to the API.
/// It encapsulates the configuration of HTTP methods, request bodies, headers,
/// query parameters, and multipart form data.
///
/// All generated requests are returned as `QueryBuilder` instances, allowing
/// additional configuration before execution.
///
/// This type is `Sendable`, making it safe for use in Swift concurrency contexts.
public final class RequestBuilder: Sendable {
    
    // MARK: - Properties
    
    /// The API endpoint associated with this request.
    private let endpoint: Endpoint
    
    /// The client configuration used for request construction.
    private let config: ClientConfig
    
    // MARK: - Initialization
    
    /// Creates a new request builder for a given API `endpoint`.
    ///
    /// - Parameters:
    ///   - endpoint: The target API endpoint.
    ///   - config: The client configuration to use for the request.
    init(endpoint: Endpoint, config: ClientConfig) {
        self.endpoint = endpoint
        self.config = config
    }
    
    // MARK: - GET
    
    /// Creates a `GET` request.
    ///
    /// - Parameter headers: Additional request headers (default: empty).
    /// - Returns: A `QueryBuilder` for further customization.
    public func get(
        headers: HeaderFields = [:]
    ) -> ClientBuilder {
        let resource = Resource(method: .get, headers: headers, endpoint: endpoint)
        return ClientBuilder(resource: resource, config: config)
    }
    
    // MARK: - POST
    
    /// Creates a `POST` request with an encodable body.
    ///
    /// - Parameters:
    ///   - request: The encodable request body.
    ///   - headers: Additional request headers (default: empty).
    /// - Returns: A `QueryBuilder` for further customization.
    public func post<T: Encodable & Sendable>(
        _ request: T,
        headers: HeaderFields = [:]
    ) -> ClientBuilder {
        let resource = Resource(
            request: request,
            method: .post,
            headers: headers,
            endpoint: endpoint
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    /// Creates a `POST` request with multipart form data.
    ///
    /// - Parameters:
    ///   - form: The multipart form data payload.
    ///   - headers: Additional request headers (default: empty).
    ///   - boundary: The multipart boundary string (default: a random UUID).
    ///   - caseType: The case style for encoding keys (default: `.snakeCase` or value from config).
    /// - Throws: An error if form data generation fails.
    /// - Returns: A `QueryBuilder` for further customization.
    public func post(
        multipart: Encodable & Sendable,
        headers: HeaderFields = [:],
        caseType: CaseType? = nil
    ) throws -> ClientBuilder {
        let resource = try multiPartResource(
            multipart: multipart,
            method: .post,
            headers: headers,
            caseType: caseType ?? config.caseType
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    // MARK: - PUT
    
    /// Creates a `PUT` request with an encodable body.
    public func put<T: Encodable & Sendable>(
        _ request: T,
        headers: HeaderFields = [:]
    ) -> ClientBuilder {
        let resource = Resource(
            request: request,
            method: .put,
            headers: headers,
            endpoint: endpoint
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    /// Creates a `PUT` request with multipart form data.
    public func put(
        multipart: Encodable & Sendable,
        headers: HeaderFields = [:],
        caseType: CaseType? = nil
    ) throws -> ClientBuilder {
        let resource = try multiPartResource(
            multipart: multipart,
            method: .put,
            headers: headers,
            caseType: caseType ?? config.caseType
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    // MARK: - PATCH
    
    /// Creates a `PATCH` request with an encodable body.
    public func patch<T: Encodable & Sendable>(
        _ request: T,
        headers: HeaderFields = [:]
    ) -> ClientBuilder {
        let resource = Resource(
            request: request,
            method: .patch,
            headers: headers,
            endpoint: endpoint
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    /// Creates a `PATCH` request with multipart form data.
    public func patch(
        multipart: Encodable & Sendable,
        headers: HeaderFields = [:],
        caseType: CaseType? = nil
    ) throws -> ClientBuilder {
        let resource = try multiPartResource(
            multipart: multipart,
            method: .patch,
            headers: headers,
            caseType: caseType ?? config.caseType
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    // MARK: - DELETE
    
    /// Creates a `DELETE` request.
    ///
    /// - Parameter headers: Additional request headers (default: empty).
    /// - Returns: A `QueryBuilder` for further customization.
    public func delete(
        headers: HeaderFields = [:]
    ) -> ClientBuilder {
        let resource = Resource(method: .delete, headers: headers, endpoint: endpoint)
        return ClientBuilder(resource: resource, config: config)
    }
    
    
    // MARK: - Download
    
    public func download(
        headers: HeaderFields = [:]
    ) -> DownloadBuilder {
        let resource = Resource(method: .get, headers: headers, endpoint: endpoint)
        return DownloadBuilder(resource: resource, config: config)
    }
    
    // MARK: - Helpers
    
    private func multiPartResource(
        multipart: Encodable & Sendable,
        method: HTTPMethod,
        headers: HeaderFields,
        caseType: CaseType
    ) throws -> Resource {
        let builder = MultiPartBuilder(caseType: caseType)
        let data = try builder.generateFormData(multipart)
        let headers = headers.merging(builder.boundaryHeader, uniquingKeysWith: { current, _ in current })
        let resource = Resource(multipartData: data, method: method, headers: headers, endpoint: endpoint)
        return resource
    }
}
