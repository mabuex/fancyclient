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
    
    /// Shared cookie storage used by all requests in this builder.
    let sharedCookieStorage = HTTPCookieStorage.shared
    
    /// Configures the `URLSession` to always accept cookies
    /// and store them in the shared cookie storage.
    var sessionConfig: URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = self.config.httpCookieAcceptPolicy
        config.httpCookieStorage = sharedCookieStorage
        return config
    }
    
    /// Builds a `URLRequest` based on the current `resource` and `config`.
    /// - Constructs the full endpoint URL from the base URL + resource path.
    /// - Adds all HTTP headers from the `resource`.
    /// - Appends any stored cookies to the request.
    /// - Logs debug information if `config.debug` is enabled.
    var baseRequest: URLRequest {
        // Build the endpoint URL and collect headers/method
        let url = resource.buildEndpointUrl(config.baseUrl)
        let headers = resource.buildHeaderFields()
        let httpMethod = resource.method
      
        // Debug logging for URL and headers
        if config.debug {
            print("🌐 API URL: \(url.absoluteString)")
            headers.forEach { print($0.key, $0.value) }
            print("\n")
        }
        
        // Initialize the request
        var request = URLRequest(url: url)
        
        // Attach HTTP headers
        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Attach cookies (if available) for this URL
        if let cookies = sharedCookieStorage.cookies(for: url) {
            let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
            cookieHeader.forEach {
                request.setValue($0.value, forHTTPHeaderField: $0.key)
            }
        }
        
        // Set HTTP method (GET, POST, etc.)
        request.httpMethod = httpMethod.rawValue
        
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
}
