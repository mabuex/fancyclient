//
//  BaseBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/15/25.
//

import Foundation
import os

/// A builder responsible for constructing and executing HTTP requests against an API.
///
/// This class holds an API `resource` (endpoint, method, headers, body, etc.)
/// and a `config` (base URL, global headers, debug settings, etc.).
/// It ensures thread-safe access to its `resource` property and supports
/// features like cookie handling and request logging.
public class BaseBuilder: @unchecked Sendable {
    
    /// Lock to synchronize access to `_resource` for thread safety.
    private let lock = OSAllocatedUnfairLock()
    
    /// The underlying resource object holding the endpoint details.
    /// Access should be thread-safe via the `resource` computed property.
    var _resource: Resource
    
    /// Configuration for this API client (e.g., base URL, debug mode).
    var config: ClientConfig
    
    /// Thread-safe accessor for the `Resource` object.
    /// - `get`: Returns a copy of the current `_resource` under lock.
    /// - `set`: Updates `_resource` under lock to prevent race conditions.
    var resource: Resource {
        get { lock.withLock { _resource } }
        set { lock.withLock { _resource = newValue } }
    }
    
    /// Builds a `URLRequest` based on the current `resource` and `config`.
    ///
    /// - Constructs the full endpoint URL from the `baseUrl` and the resource path.
    /// - Applies the HTTP method defined by the resource.
    /// - Adds all HTTP headers and cookies (if policy allows).
    /// - Logs URL, method, headers, and cookies when `config.debug` is enabled.
    ///
    /// - Returns: A fully constructed `URLRequest` ready to be sent with `URLSession`.
    var baseRequest: URLRequest {
        let url = resource.buildEndpointUrl(config.baseUrl)
        let httpMethod = resource.method
        
        // Merge headers + cookies
        var allHeaders = resource.buildHeaderFields()
        allHeaders.merge(cookiesHeader(for: url)) { current, _ in current }
        
        // Build the request
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.allHTTPHeaderFields = allHeaders
        
        // Debug logging
        if config.debug {
            logRequest(url, method: httpMethod, headers: allHeaders)
        }
        
        return request
    }
    
    // MARK: - Initializer
    
    /// Creates a new `BaseBuilder` instance.
    /// - Parameters:
    ///   - resource: The initial API resource to use for building requests.
    ///   - config: The client configuration (base URL, default headers, debug flag, etc.).
    init(resource: Resource, config: ClientConfig) {
        self._resource = resource
        self.config = config
    }
    
    // MARK: - Helpers
    
    private func cookiesHeader(for url: URL) -> [String: String] {
        guard config.sessionConfig.httpCookieAcceptPolicy == .always,
              let cookies = config.sessionConfig.httpCookieStorage?.cookies(for: url),
              !cookies.isEmpty else {
            return [:]
        }
        return HTTPCookie.requestHeaderFields(with: cookies)
    }
    
    private func logRequest(_ url: URL, method: HTTPMethod, headers: [String: String]) {
        logger.debug("""
        🌐 URL: \(url.absoluteString)
        ⚡ Method: \(method.rawValue)
        📋 Headers: \(headers)
        """)
    }
}
