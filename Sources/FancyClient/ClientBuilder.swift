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
/// - Handling cookies automatically.
/// - Logging detailed request/response information when `debug` mode is enabled.
///
/// Marked as `@unchecked Sendable` because `BaseBuilder` holds mutable state,
/// but all access is internally synchronized via locks.
public class ClientBuilder: BaseBuilder, QueryBuilder, @unchecked Sendable {
    
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
    public func query(_ query: Encodable & Sendable, caseType: CaseType? = nil) throws -> Self {
        resource.query = try getQueryItems(query, caseType: caseType ?? config.caseType)
        return self
    }
    
    /// Executes the HTTP request for the current resource and decodes the response into the specified type.
    ///
    /// Builds a `URLRequest` from the current `resource` and attaches any form data
    /// if present. Executes the request asynchronously and decodes the JSON response
    /// into a model of type `T`.
    ///
    /// - Parameter completion: An optional closure that receives any cookies returned
    ///   in the response.
    /// - Returns: The decoded model object of type `T`.
    /// - Throws: `ClientError` variants for networking, encoding/decoding failures,
    ///   or invalid HTTP status codes.
    public func execute<T: Decodable>(
        completion: (([HTTPCookie]) -> Void)? = nil
    ) async throws -> T {
        var request = baseRequest
        
        // Attach form data if available
        if let formData = resource.multipartData {
            request.httpBody = formData
            if config.debug, let str = String(data: formData, encoding: .utf8) {
                print("\(str)\n")
            }
        }
        
        // Perform the network request
        let (data, cookies) = try await self.request(request)
        
        // Pass cookies to the completion handler if provided
        if let completion {
            completion(cookies ?? [])
        }
        
        // Decode and return the response
        return try decode(data) as T
    }
    
    // MARK: - Private Methods
    
    /// Executes the network call using `URLSession`.
    ///
    /// - Uses `upload(for:from:)` if the resource contains an encodable request body.
    /// - Uses `data(for:)` if no request body is present.
    ///
    /// - Parameter urlRequest: The prepared `URLRequest`.
    /// - Returns: The raw `Data` and any `HTTPCookie` objects from the response.
    /// - Throws: `ClientError.dataTaskError` if no valid data/response is received.
    private func request(_ urlRequest: URLRequest) async throws -> (Data, [HTTPCookie]?) {
        do {
            if let request = resource.request {
                let (data, response) = try await URLSession.shared.upload(
                    for: urlRequest,
                    from: encode(request)
                )
                return try self.response(data: data, response: response)
            }
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            return try self.response(data: data, response: response)
        } catch {
            throw error
        }
    }
    
    /// Validates the HTTP response and extracts cookies if present.
    ///
    /// - Checks that the status code is in the `200..<300` range.
    /// - Returns the data and cookies if valid.
    /// - Throws: `ClientError.invalidStatusCode` if the status code is not successful.
    private func response(data: Data?, response: URLResponse?) throws -> (Data, [HTTPCookie]?) {
        guard let data, let response = response as? HTTPURLResponse else {
            throw ClientError.dataTaskError
        }
        
        if (200..<300).contains(response.statusCode) {
            if let fields = response.allHeaderFields as? [String: String],
               let url = response.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                sharedCookieStorage.setCookies(cookies, for: url, mainDocumentURL: nil)
                return (data, cookies)
            }
            return (data, nil)
        } else {
            if config.debug {
                print("❌ Invalid Status Code: \(response.statusCode)\n")
            }
            throw ClientError.invalidStatusCode(response.statusCode, data)
        }
    }
    
    /// Encodes an `Encodable` object into JSON data using the client's encoder.
    ///
    /// - Parameter request: The encodable request body.
    /// - Returns: The encoded JSON `Data`.
    /// - Throws: `ClientError.encodingError` if encoding fails.
    private func encode<T: Encodable>(_ request: T) throws -> Data {
        if config.debug {
            print("➡️ Request:\n\(request.prettyJSONString)\n")
        }
        guard let encoded = try? config.encoder.encode(request) else {
            let error = "❌ Error encoding: <\(String(describing: type(of: request.self)))>\n"
            if config.debug { print(error) }
            throw ClientError.encodingError(error)
        }
        return encoded
    }
    
    /// Decodes JSON data into a `Decodable` model using the client's decoder.
    ///
    /// - Parameter data: The raw JSON `Data` from the server.
    /// - Returns: The decoded model of type `T`.
    /// - Throws: `ClientError.decodingError` or `ClientError.corruptData` if decoding fails.
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if config.debug {
            print("⬅️ Response:\n\(data.prettyJSONString)\n")
        }
        do {
            return try config.decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            if config.debug {
                print("❌ Decoding Error: <\(String(describing: type(of: T.self)))>\n\(error.prettyDescription)\n")
            }
            throw ClientError.decodingError(error.prettyDescription)
        } catch {
            if config.debug { print("❌ Error: \(error.localizedDescription)\n") }
            throw ClientError.corruptData
        }
    }
}
