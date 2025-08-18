//
//  Utils.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/13/25.
//

import Foundation

/// A utility type containing helper functions for common data transformations.
struct Utils {
    /// Converts a value of any type into its `String` representation.
    ///
    /// This method attempts to convert known primitive and collection types
    /// into a human-readable string format, falling back to Swift's default
    /// `String(describing:)` representation for unknown types.
    ///
    /// ### Type-specific behavior:
    /// - **String**: Returned as-is.
    /// - **Int**: Converted using `String(int)`.
    /// - **Double**: Converted using `String(double)`.
    /// - **Float**: Converted using `String(float)`.
    /// - **Bool**: `"true"` or `"false"`.
    /// - **Date**: Converted using `String(describing: date)`
    /// - **[Any]** (Array): Recursively converts each element, joining them
    ///   with `", "` inside square brackets.
    /// - **Other types**: Uses `"\(any)"`, which calls `String(describing:)`.
    ///
    /// ### Example:
    /// ```swift
    /// Utils.anyToString("Hello")                // "Hello"
    /// Utils.anyToString(42)                     // "42"
    /// Utils.anyToString(3.14)                    // "3.14"
    /// Utils.anyToString(true)                    // "true"
    /// Utils.anyToString(Date(timeIntervalSince1970: 0))
    /// // "1970-01-01 00:00:00 +0000" (default Date description)
    /// Utils.anyToString([1, "two", false])       // "[1, two, false]"
    /// ```
    ///
    /// - Parameter any: The value to convert.
    /// - Returns: A `String` representation of the input value.
    static func anyToString(_ any: Any) -> String {
        if let string = any as? String {
            return string
        }
        
        if let int = any as? Int {
            return String(int)
        }
        
        if let double = any as? Double {
            return String(double)
        }
        
        if let float = any as? Float {
            return String(float)
        }
        
        if let bool = any as? Bool {
            return bool ? "true" : "false"
        }
        
        if let date = any as? Date {
            return String(describing: date)
        }
        
        if let array = any as? [Any] {
            return "[" + array.map(anyToString).joined(separator: ", ") + "]"
        }
        
        return "\(any)"
    }
    
    
    static func randomHexString() -> String {
        var bytes = [UInt8](repeating: 0, count: 8)
            _ = SecRandomCopyBytes(kSecRandomDefault, 8, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
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
