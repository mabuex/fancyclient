//
//  ClientBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation

/// A specialized request builder for executing API calls using a `Client`.
///
/// `ClientBuilder` extends `BaseBuilder` and adds capabilities for:
/// - Attaching query parameters in a type-safe, case-style aware way.
/// - Executing requests and decoding responses into strongly typed models.
/// - Logging detailed request/response information when `debug` mode is enabled.
///
/// Marked as `@unchecked Sendable` because `BaseBuilder` holds mutable state,
/// but all access is internally synchronized via locks.
public class ClientBuilder: BaseBuilder, QueryBuilder, @unchecked Sendable {

    // MARK: - Properties
    
    /// Lazily initialized, reusable `URLSession` for this builder.
    private lazy var session: URLSession = URLSession(configuration: config.sessionConfig)

    // MARK: - Public Methods

    /// Attaches a query parameter object to the request being built.
    ///
    /// Encodes an `Encodable & Sendable` object into URL query parameters.
    /// Uses the specified `caseType` for key conversion, defaulting to the builder's
    /// configured `config.caseType` if none is provided.
    ///
    /// - Parameters:
    ///   - query: The object containing query parameters to append.
    ///   - caseType: The desired key casing (e.g., `.snakeCase` or `.camelCase`).
    /// - Returns: The same `ClientBuilder` instance for method chaining.
    /// - Throws: Any error encountered while encoding query parameters.
    public func query(_ query: some Encodable & Sendable, caseType: CaseType? = nil) -> Self {
        resource.query = getQueryItems(query, caseType: caseType ?? config.caseType)
        return self
    }

    /// Executes the HTTP request for the current resource and decodes the response into the specified type.
    ///
    /// Builds a `URLRequest` from the current `resource` and attaches any form data
    /// if present. Executes the request asynchronously and decodes the JSON response
    /// into a model of type `T`.
    ///
    /// - Returns: The decoded model object of type `T`.
    /// - Throws: `ClientError` variants for networking, encoding/decoding failures,
    ///   or invalid HTTP status codes.
    public func execute<T: Decodable>() async throws -> T {
        var request = baseRequest
        
        let httpBody: Data?
        // Attach form data if available
        if let multipart = resource.multipartData {
            httpBody = multipart
        } else if let request = resource.request {
            httpBody = try encode(request)
        } else {
            httpBody = nil
        }
        
        if let httpBody {
            request.httpBody = httpBody
        }
        
        // Perform the network request
        let data = try await performRequest(request)
        
        // Decode and return the response
        return try decode(data)
    }

    // MARK: - Private Methods

    /// Performs the actual network request.
    ///
    /// - Parameter urlRequest: The prepared `URLRequest`.
    /// - Returns: The raw `Data` from the response.
    /// - Throws: `ClientError.dataTaskError` if no valid data/response is received.
    private func performRequest(_ urlRequest: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: urlRequest)
        return try handleResponse(data: data, response: response)
    }

    /// Validates the HTTP response.
    ///
    /// - Checks that the status code is in the `200..<300` range.
    /// - Returns: The response data if valid.
    /// - Throws: `ClientError.invalidStatusCode` if the status code is not successful.
    private func handleResponse(data: Data?, response: URLResponse?) throws -> Data {
        guard let data, let response = response as? HTTPURLResponse else {
            throw ClientError.dataTaskError
        }

        guard (200..<300).contains(response.statusCode) else {
            throw ClientError.invalidStatusCode(response.statusCode, data)
        }

        return data
    }

    /// Encodes an `Encodable` object into JSON data using the client's encoder.
    ///
    /// - Parameter request: The encodable request body.
    /// - Returns: The encoded JSON `Data`.
    /// - Throws: `ClientError.encodingError` if encoding fails.
    private func encode<T: Encodable>(_ request: T) throws -> Data {
        if config.debug { logger.debug("➡️ Request:\n\(request.prettyJSONString)\n") }
        guard let encoded = try? config.encoder.encode(request) else {
            throw ClientError.encodingError("❌ Encoding error: \(String(describing: type(of: request.self)))")
        }
        return encoded
    }

    /// Decodes JSON data into a `Decodable` model using the client's decoder.
    ///
    /// - Parameter data: The raw JSON `Data` from the server.
    /// - Returns: The decoded model of type `T`.
    /// - Throws: `ClientError.decodingError` or `ClientError.corruptData` if decoding fails.
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if config.debug { logger.debug("⬅️ Response:\n\(data.prettyJSONString)\n") }
        do {
            return try config.decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw ClientError.decodingError(error.prettyDescription)
        } catch {
            throw ClientError.corruptData
        }
    }
}

