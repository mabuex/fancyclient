//
//  SocketBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/19/25.
//

import Foundation

import Foundation

/// A fluent builder for configuring and creating WebSocket connections.
///
/// `SocketBuilder` provides a type-safe way to construct a WebSocket request
/// and produce a fully configured ``SocketStream`` instance. It supports:
///
/// - Attaching query parameters from any `Encodable` type
/// - Respecting the builder's global configuration (e.g. case type, session config)
/// - Creating a `SocketStream` with reconnect and keep-alive options
public class SocketBuilder: BaseBuilder, QueryBuilder, @unchecked Sendable {
    // MARK: - Public Methods
    
    /// Attaches query parameters to the WebSocket request.
    ///
    /// Encodes the provided `query` object into `URLQueryItem`s and appends them
    /// to the request's URL. This makes it easy to send structured query data
    /// (e.g. room IDs, auth tokens) in a type-safe way.
    ///
    /// - Parameters:
    ///   - query: Any type conforming to both `Encodable` and `Sendable`.
    ///            Its properties will be encoded as query parameters.
    ///   - caseType: Optional key casing strategy. Defaults to the builder's
    ///               configured `CaseType` if not provided.
    ///
    /// - Returns: The same ``SocketBuilder`` instance, enabling method chaining.
    /// - Throws: An error if the query object cannot be encoded.
    public func query(_ query: some Encodable & Sendable, caseType: CaseType? = nil) -> Self {
        resource.query = getQueryItems(query, caseType: caseType ?? config.caseType)
        return self
    }
    
    /// Builds and returns a configured WebSocket client.
    ///
    /// Creates a new ``SocketStream`` from the builder's `baseRequest` and
    /// configuration. The returned stream supports async event iteration,
    /// automatic reconnect with exponential backoff, and an optional keep-alive
    /// ping loop.
    ///
    /// - Parameters:
    ///   - pingInterval: Interval in seconds between keep-alive pings.
    ///                   Defaults to `25`. Set to `0` to disable.
    ///   - maxReconnectAttempts: Maximum number of reconnect attempts before
    ///                           giving up. `nil` means unlimited retries.
    ///
    /// - Returns: A fully configured ``SocketStream`` instance.
    public func stream(
        pingInterval: TimeInterval = 25,
        maxReconnectAttempts: Int? = nil
    ) -> SocketStream {
        SocketStream(
            request: baseRequest,
            config: config.sessionConfig,
            pingInterval: pingInterval,
            maxReconnectAttempts: maxReconnectAttempts
        )
    }
}
