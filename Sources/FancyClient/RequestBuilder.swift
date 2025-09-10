//
//  RequestBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation

/// A type-safe, chainable builder for constructing HTTP requests (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`)
/// or WebSocket connections targeting a given `Endpoint`.
///
/// `RequestBuilder` acts as the entry point for creating requests to the API.
/// It encapsulates the configuration of HTTP methods, request bodies, headers,
/// query parameters, and multipart form data.
///
/// All generated requests return specialized builder types (`ClientBuilder`, `DownloadBuilder`, `SocketBuilder`)
/// that support additional configuration before execution.
///
/// This type is `Sendable`, making it safe for use in Swift concurrency contexts.
///
/// Example:
/// ```swift
/// // JSON POST
/// let user = UserRequest(name: "Alice")
/// let response = try await client
///     .endpoint(.users)
///     .post(user)
///     .execute()
///
/// // File Upload
/// let upload = try await client
///     .endpoint(.files)
///     .post(multipart: fileData)
///     .execute()
///
/// // WebSocket
/// let stream = try await client
///     .endpoint(.chat(for: "general"))
///     .socket()
///     .stream()
/// ```
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
    /// - Returns: A `ClientBuilder` for further customization.
    ///
    /// Example:
    /// ```swift
    /// let users = try await client
    ///     .endpoint(.users)
    ///     .get()
    ///     .execute()
    /// ```
    public func get(headers: HeaderFields = [:]) -> ClientBuilder {
        let resource = Resource(method: .get, headers: headers, endpoint: endpoint)
        return ClientBuilder(resource: resource, config: config)
    }
    
    // MARK: - POST
    
    /// Creates a `POST` request with an encodable body.
    ///
    /// - Parameters:
    ///   - request: The encodable request body.
    ///   - headers: Additional request headers (default: empty).
    /// - Returns: A `ClientBuilder` for further customization.
    ///
    /// Example:
    /// ```swift
    /// let response = try await client
    ///     .endpoint(.users)
    ///     .post(NewUser(name: "Alice"))
    ///     .execute()
    /// ```
    public func post(
        _ request: some Encodable & Sendable,
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
    
    /// Creates a `POST` request without an encodable body.
    ///
    /// - Parameters:
    ///   - headers: Additional request headers (default: empty).
    /// - Returns: A `ClientBuilder` for further customization.
    ///
    /// Example:
    /// ```swift
    /// let response = try await client
    ///     .endpoint(.users)
    ///     .post()
    ///     .execute()
    /// ```
    public func post(
        headers: HeaderFields = [:]
    ) -> ClientBuilder {
        let resource = Resource(
            method: .post,
            headers: headers,
            endpoint: endpoint
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    /// Creates a `POST` request with multipart form data.
    ///
    /// - Parameters:
    ///   - multipart: The multipart form data payload.
    ///   - headers: Additional request headers (default: empty).
    ///   - caseType: The case style for encoding keys (default: `.snakeCase` or the value from config).
    /// - Throws: An error if form data generation fails.
    /// - Returns: A `ClientBuilder` for further customization.
    ///
    /// Example:
    /// ```swift
    /// let upload = try await client
    ///     .endpoint(.files)
    ///     .post(multipart: UploadForm(file: data))
    ///     .execute()
    /// ```
    public func post(
        multipart: some Encodable & Sendable,
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
    ///
    /// Example:
    /// ```swift
    /// let updated = try await client
    ///     .endpoint(.user(id: "123"))
    ///     .put(UpdateUser(name: "Bob"))
    ///     .execute()
    /// ```
    public func put(
        _ request: some Encodable & Sendable,
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
    
    /// Creates a `PUT` request without an encodable body.
    ///
    /// Example:
    /// ```swift
    /// let updated = try await client
    ///     .endpoint(.user(id: "123"))
    ///     .put()
    ///     .execute()
    /// ```
    public func put(
        headers: HeaderFields = [:]
    ) -> ClientBuilder {
        let resource = Resource(
            method: .put,
            headers: headers,
            endpoint: endpoint
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    /// Creates a `PUT` request with multipart form data.
    public func put(
        multipart: some Encodable & Sendable,
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
    public func patch(
        _ request: some Encodable & Sendable,
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
    
    /// Creates a `PATCH` request without an encodable body.
    public func patch(
        headers: HeaderFields = [:]
    ) -> ClientBuilder {        
        let resource = Resource(
            method: .patch,
            headers: headers,
            endpoint: endpoint
        )
        return ClientBuilder(resource: resource, config: config)
    }
    
    /// Creates a `PATCH` request with multipart form data.
    public func patch(
        multipart: some Encodable & Sendable,
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
    /// Example:
    /// ```swift
    /// try await client
    ///     .endpoint(.user(id: "123"))
    ///     .delete()
    ///     .execute()
    /// ```
    public func delete(headers: HeaderFields = [:]) -> ClientBuilder {
        let resource = Resource(method: .delete, headers: headers, endpoint: endpoint)
        return ClientBuilder(resource: resource, config: config)
    }
    
    // MARK: - Download
    
    /// Creates a download request that streams progress updates.
    ///
    /// Example:
    /// ```swift
    /// let download = try await client
    ///     .endpoint(.download(fileID: "123"))
    ///     .download()
    ///     .execute { events in
    ///         for await event in events {
    ///             switch event {
    ///             case let .progress(current, total): print("📈", current, "/", total)
    ///             case let .completed(url): print("✅ Saved to:", url)
    ///             case let .failed(error): print("❌", error.localizedDescription)
    ///             default: break
    ///             }
    ///         }
    ///     }
    /// ```
    public func download(headers: HeaderFields = [:]) -> DownloadBuilder {
        let resource = Resource(method: .get, headers: headers, endpoint: endpoint)
        return DownloadBuilder(resource: resource, config: config)
    }
    
    // MARK: - WebSocket
    
    /// Creates a WebSocket request.
    ///
    /// Example:
    /// ```swift
    /// let stream = try await client
    ///     .endpoint(.chat(for: "general"))
    ///     .socket()
    ///     .stream()
    /// ```
    public func socket(
        encrypted: Bool = true,
        headers: HeaderFields = [:]
    ) -> SocketBuilder {
        let resource = Resource(encrypted: encrypted, headers: headers, endpoint: endpoint)
        return SocketBuilder(resource: resource, config: config)
    }
    
    // MARK: - Helpers
    
    private func multiPartResource(
        multipart: some Encodable & Sendable,
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
