//
//  Client.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation
import OSLog

/// A generic API client that builds and executes requests to a given set of endpoints.
///
/// `Client` is parameterized by an `Endpoint` type, allowing it to work with
/// a specific enumeration or struct that defines your API endpoints.
/// It stores a `ClientConfig` containing all the global configuration values
/// (e.g., base URL, JSON encoder/decoder, cookie policy, etc.).
///
/// This client is responsible for creating `BaseBuilder` instances (not shown here)
/// to prepare and send requests.
public final class Client<E: Endpoint>: Sendable {
    
    /// The configuration settings used by this API client (base URL, encoders, etc.).
    private let config: ClientConfig
    
    /// Creates a new API client with the given base settings.
    ///
    /// Use this initializer to set up a reusable client for communicating with your API.
    /// It can be configured with custom JSON coders, key conversion strategies,
    /// cookie policies, download paths, and optional debug logging.
    ///
    /// - Parameters:
    ///   - baseUrl: The base URL that all endpoint paths will be appended to.
    ///   - encoder: The `JSONEncoder` used when encoding request bodies.
    ///              Defaults to `ClientConfig.defaultEncoder`.
    ///   - decoder: The `JSONDecoder` used when decoding response bodies.
    ///              Defaults to `ClientConfig.defaultDecoder`.
    ///   - caseType: The default `CaseType` for encoding/decoding keys
    ///               (e.g., `.snakeCase` or `.camelCase`). Defaults to `.snakeCase`.
    ///   - httpCookieAcceptPolicy: The policy for accepting HTTP cookies.
    ///                             Defaults to `.always`.
    ///   - destinationFolder: Local directory name where downloaded files will be stored.
    ///                   Defaults to `"downloads"`.
    ///   - debug: Enables verbose logging of requests and responses if `true`.
    ///            Defaults to `false`.
    public init(
        baseUrl: URL,
        encoder: JSONEncoder = ClientConfig.defaultEncoder,
        decoder: JSONDecoder = ClientConfig.defaultDecoder,
        defaultCaseType caseType: CaseType = .snakeCase,
        httpCookieAcceptPolicy: HTTPCookie.AcceptPolicy = .always,
        destinationFolder: String = "downloads",
        debug: Bool = false
    ) {
        self.config = ClientConfig(
            baseUrl: baseUrl,
            encoder: encoder,
            decoder: decoder,
            httpCookieAcceptPolicy: httpCookieAcceptPolicy,
            caseType: caseType,
            destinationFolder: destinationFolder,
            debug: debug
        )
        
        if debug {
            logger.debug("Initialized FancyClient with debug enabled.")
        }
    }
    
    /// Creates a request builder for the given endpoint.
    ///
    /// - Parameter endpoint: The endpoint to build a request for.
    /// - Returns: A `RequestBuilder` configured for this client and endpoint.
    public func endpoint(_ endpoint: E) -> RequestBuilder {
        return RequestBuilder(endpoint: endpoint, config: config)
    }
}

/// A dictionary representing HTTP header fields in a request, where
/// the key is the header name and the value is the header value.
public typealias HeaderFields = [String: String]

// MARK: - Endpoint Protocol

/// Defines an API endpoint that can be used with the `Client`.
public protocol Endpoint: Sendable {
    /// The path component of the endpoint (appended to the base URL).
    var path: String { get }
    
    /// Any additional HTTP headers required by this endpoint.
    var headers: HeaderFields { get }
}

// MARK: - Client Configuration

/// Configuration settings for the `Client`.
public struct ClientConfig: Sendable {
    public var baseUrl: URL
    public var encoder: JSONEncoder
    public var decoder: JSONDecoder
    public var httpCookieAcceptPolicy: HTTPCookie.AcceptPolicy
    public var caseType: CaseType
    public var destinationFolder: String
    public var debug: Bool
}

extension ClientConfig {
    /// A default JSON decoder configured with snake_case key decoding
    /// and ISO 8601 date decoding.
    public static let defaultDecoder = { () -> JSONDecoder in
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    /// A default JSON encoder configured with snake_case key encoding
    /// and ISO 8601 date encoding.
    public static let defaultEncoder = { () -> JSONEncoder in
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension ClientConfig {
    var directoryURL: URL {
        URL.documentsDirectory
            .appending(path: "\(destinationFolder)", directoryHint: .isDirectory)
    }
}

// MARK: - Case Type

/// Represents different string case conversion strategies.
public enum CaseType: Sendable {
    case snakeCase, camelCase, kebabCase, pascalCase
    
    /// Converts the given string to the case type.
    ///
    /// - Parameter string: The string to convert.
    /// - Returns: The converted string.
    public func convert(_ string: String) -> String {
        switch self {
        case .snakeCase:
            string.toSnakeCase
        case .camelCase:
            string.toCamelCase
        case .kebabCase:
            string.toKebabCase
        case .pascalCase:
            string.toPascalCase
        }
    }
}

// MARK: - HTTP Methods

/// Supported HTTP request methods.
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Client Error

/// Common errors that can occur when using the `Client`.
public enum ClientError: Error, LocalizedError, Sendable {
    /// The endpoint URL could not be constructed.
    case invalidURL
    /// The response returned an invalid HTTP status code.
    case invalidStatusCode(Int, Data)
    /// An error occurred during the URL session data task.
    case dataTaskError
    /// The received data is corrupt or unreadable.
    case corruptData
    /// The data could not be decoded into the expected type.
    case decodingError(String)
    /// The request body could not be encoded.
    case encodingError(String)
    /// The JSON could not be serialized.
    case jsonSerializationError
    /// The requested resource could not be found.
    case missingResource
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "The endpoint URL is invalid.")
        case .invalidStatusCode:
            return String(localized: "Invalid HTTP response code.")
        case .dataTaskError:
            return String(localized: "An error occurred during the network request.")
        case .corruptData:
            return String(localized: "The received data is corrupt.")
        case .decodingError(let message):
            return String(localized: "Failed to decode data. \(message)")
        case .encodingError(let message):
            return String(localized: "Failed to encode data. \(message)")
        case .jsonSerializationError:
            return String(localized: "Failed to serialize JSON.")
        case .missingResource:
            return String(localized: "The requested resource is missing.")
        }
    }
}

// MARK: - Logger

let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "fancyclient.debugging"
)
