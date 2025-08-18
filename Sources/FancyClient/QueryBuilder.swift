//
//  QueryBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/15/25.
//

import Foundation

/// A protocol that provides functionality to build URL query parameters from an `Encodable` object.
public protocol QueryBuilder {
    /// Converts an `Encodable & Sendable` object into query parameters for a URL.
    ///
    /// - Parameters:
    ///   - query: The object to convert into query items.
    ///   - caseType: Optional key casing style for the query parameter names.
    /// - Returns: Self, allowing method chaining.
    /// - Throws: If encoding the object into a dictionary fails.
    func query(_ query: Encodable & Sendable, caseType: CaseType?) throws -> Self
}

extension QueryBuilder {
    
    // MARK: - QueryBuilder Helpers
    
    /// Converts an `Encodable` object into an array of `URLQueryItem` objects.
    ///
    /// This helper uses a `DictionaryEncoder` to first convert the object
    /// into a dictionary, then maps the dictionary into query items,
    /// applying the provided `CaseType` to transform the keys.
    ///
    /// - Parameters:
    ///   - values: The object to convert, conforming to `Encodable & Sendable`.
    ///   - caseType: The key casing style for query parameter names.
    /// - Returns: An array of `URLQueryItem` objects representing the encoded properties.
    /// - Throws: An error if encoding the object into a dictionary fails.
    func getQueryItems<T: Encodable & Sendable>(_ values: T, caseType: CaseType) throws -> [URLQueryItem] {
        // Encode the object into a dictionary using the custom DictionaryEncoder
        let encoder = DictionaryEncoder()
        try values.encode(to: encoder)
        
        // Map the dictionary into URLQueryItem array
        return encoder.storage.dict.map {
            URLQueryItem(
                name: caseType.convert($0.key),  // Apply key casing
                value: Utils.anyToString($0.value) // Convert value to String
            )
        }
    }
}
