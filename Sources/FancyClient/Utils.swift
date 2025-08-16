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
