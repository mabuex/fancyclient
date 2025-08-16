//
//  Extensions.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Data Extensions

extension Data {
    /// Appends a UTF-8 encoded string to the `Data` object.
    ///
    /// - Parameter newElement: The string to append.
    mutating func append(_ newElement: String) {
        if let data = newElement.data(using: .utf8) {
            self.append(data)
        }
    }
    
    /// Returns a pretty-printed JSON string representation of the `Data`.
    ///
    /// - If the data is not valid JSON, returns the error's description.
    var prettyJSONString: String {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: [])
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            return String(data: data, encoding: .utf8) ?? "Failed to prettify JSON."
        } catch {
            return error.localizedDescription
        }
    }
    
    /// Prints the pretty-printed JSON string to the console.
    func prettyPrintJSON() {
        print(prettyJSONString)
    }
}

// MARK: - Encodable Extensions

extension Encodable {
    /// Returns a pretty-printed JSON string representation of the object.
    ///
    /// - If encoding fails, returns `"Failed to prettify JSON."`.
    var prettyJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let jsonData = try? encoder.encode(self) else {
            return "Failed to prettify JSON."
        }
        return String(data: jsonData, encoding: .utf8) ?? "Failed to prettify JSON."
    }
    
    /// Prints the pretty-printed JSON string to the console.
    func prettyPrintJSON() {
        print(prettyJSONString)
    }
}

// MARK: - String Extensions

extension String {
    /// Converts a camelCase or PascalCase string to snake_case.
    var toSnakeCase: String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try! NSRegularExpression(pattern: pattern)
        let snakeCasedString = regex.stringByReplacingMatches(
            in: self,
            range: NSRange(location: 0, length: utf16.count),
            withTemplate: "$1_$2"
        )
        return snakeCasedString
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
    }
    
    /// Converts a snake_case string to camelCase.
    var toCamelCase: String {
        let components = split(separator: "_").map(String.init)
        guard let first = components.first else { return self }
        return components.dropFirst().reduce(first) { $0 + $1.capitalized }
    }
    
    /// Converts a camelCase or snake_case string to kebab-case.
    var toKebabCase: String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try! NSRegularExpression(pattern: pattern)
        let kebabCasedString = regex.stringByReplacingMatches(
            in: self,
            range: NSRange(location: 0, length: utf16.count),
            withTemplate: "$1-$2"
        )
        return kebabCasedString
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }
    
    /// Converts a snake_case string to PascalCase.
    var toPascalCase: String {
        split(separator: "_").map { $0.capitalized }.joined()
    }
}

// MARK: - DecodingError Extensions

public extension DecodingError {
    /// A detailed, human-readable description of the decoding error.
    var prettyDescription: String {
        switch self {
        case let .typeMismatch(type, context):
            "DecodingError.typeMismatch \(type), value \(context.prettyDescription) @ ERROR: \(localizedDescription)"
        case let .valueNotFound(type, context):
            "DecodingError.valueNotFound \(type), value \(context.prettyDescription) @ ERROR: \(localizedDescription)"
        case let .keyNotFound(key, context):
            "DecodingError.keyNotFound \(key), value \(context.prettyDescription) @ ERROR: \(localizedDescription)"
        case let .dataCorrupted(context):
            "DecodingError.dataCorrupted \(context.prettyDescription) @ ERROR: \(localizedDescription)"
        @unknown default:
            "DecodingError: \(localizedDescription)"
        }
    }
}

// MARK: - DecodingError.Context Extensions

public extension DecodingError.Context {
    /// A detailed, human-readable description of the decoding error context.
    var prettyDescription: String {
        var result = ""
        if !codingPath.isEmpty {
            result.append(codingPath.map(\.stringValue).joined(separator: "."))
            result.append(": ")
        }
        result.append(debugDescription)
        
        if let nsError = underlyingError as? NSError,
           let description = nsError.userInfo["NSDebugDescription"] as? String {
            result.append(description)
        }
        
        return result
    }
}

// MARK: - UTType Extensions

extension UTType {
    static let xmlFile = UTType(exportedAs: "public.xml", conformingTo: .text)
}

// MARK: - Dictionary Encoder

/// Internal storage class for `DictionaryEncoder`.
final class DictionaryStorage {
    var dict: [String: Any] = [:]
}

/// An encoder that encodes Swift types into `[String: Any]` dictionaries.
///
/// Only supports keyed encoding. Unkeyed and single-value encoding are not implemented.
final class DictionaryEncoder: Encoder {
    var codingPath: [any CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    let storage = DictionaryStorage()
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = DictionaryKeyedEncodingContainer<Key>(codingPath: codingPath, storage: storage)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        fatalError("Unkeyed containers not implemented")
    }
    
    func singleValueContainer() -> any SingleValueEncodingContainer {
        fatalError("Single value containers not implemented")
    }
    
    private struct DictionaryKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
        var codingPath: [any CodingKey]
        var storage: DictionaryStorage
        
        init(codingPath: [any CodingKey], storage: DictionaryStorage) {
            self.codingPath = codingPath
            self.storage = storage
        }
        
        mutating func encodeNil(forKey key: K) throws {
            storage.dict[key.stringValue] = NSNull()
        }
        
        mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws {
            storage.dict[key.stringValue] = value
        }
        
        mutating func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type,
            forKey key: K
        ) -> KeyedEncodingContainer<NestedKey> {
            storage.dict[key.stringValue] = [String: Any]()
            return KeyedEncodingContainer(
                DictionaryKeyedEncodingContainer<NestedKey>(codingPath: codingPath, storage: storage)
            )
        }
        
        mutating func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer {
            fatalError("Unkeyed containers not implemented")
        }
        
        mutating func superEncoder() -> any Encoder {
            fatalError("Super encoders not implemented")
        }
        
        mutating func superEncoder(forKey key: K) -> any Encoder {
            fatalError("Super encoders not implemented")
        }
    }
}
