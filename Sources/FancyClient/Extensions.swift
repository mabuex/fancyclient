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
