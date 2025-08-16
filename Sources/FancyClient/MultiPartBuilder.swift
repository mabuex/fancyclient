//
//  MultiFormBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/11/25.
//

import Foundation
import UniformTypeIdentifiers

/// A utility for generating `multipart/form-data` payloads from `Encodable` values.
///
/// `MultiPartBuilder` takes any `Encodable` object and converts it into a valid
/// `multipart/form-data` body. It automatically handles:
/// - **Scalars**: `String`, `Int`, `Bool`, etc.
/// - **Single file uploads**: `Data`
/// - **Multiple files**: `[Data]`
///
/// Supported MIME types include:
/// - **Images**: `jpeg`, `png`, `gif`, `bmp`, `tiff`, `webp`, `avif`, `heic`
/// - **Video**: `mp4`, `webm`, `avi`
/// - **Audio**: `mp4/m4a`, `mp3`, `wav`, `flac`, `ogg`
/// - **Documents & Archives**: `pdf`, `zip`, `gzip`, `7z`, `rar`
/// - **Structured Data**: `json`, `xml`
/// - **Text**: `plain`, `markdown`
/// - Fallback: `application/octet-stream` (unknown binary)
///
/// The boundary string is auto-generated unless specified. Property keys are
/// normalized according to the provided ``CaseType`` (default: `.snakeCase`).
///
/// ## Thread Safety
/// `MultiPartBuilder` is `Sendable` and safe for concurrent use, assuming the
/// provided values are also `Sendable`.
struct MultiPartBuilder: Sendable {
    
    // MARK: - Properties
    
    /// The multipart boundary string used to separate form-data parts.
    private let boundary: String
    
    /// The strategy for converting property names.
    private let caseType: CaseType
    
    // MARK: - Errors
    
    enum MultiPartError: Error, LocalizedError, Sendable {
        case emptyArray
        case emptyData
        case encodingFailed
        
        public var errorDescription: String? {
            switch self {
            case .emptyArray:
                String(localized: "Data array can not be empty.")
            case .emptyData:
                String(localized: "No data was provided to complete the request.")
            case .encodingFailed:
                String(localized: "Failed to encode the data. Please check the format and try again.")
            }
        }
    }
    
    // MARK: - Initializer
    
    /// Creates a new `MultiPartBuilder`.
    ///
    /// - Parameters:
    ///   - boundary: An optional custom boundary string.
    ///     If `nil`, a UUID string is generated.
    ///   - caseType: The key conversion strategy. Defaults to `.snakeCase`.
    init(caseType: CaseType = .snakeCase) {
        self.caseType = caseType
        self.boundary =  "boundary." + Utils.randomHexString()
    }
    
    /// Returns the `Content-Type` header for a multipart request.
    var boundaryHeader: HeaderFields {
        ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
    }
    
    // MARK: - Public Methods
    
    /// Generates a complete `multipart/form-data` payload from the provided encodable values.
    ///
    /// The encoding process:
    /// 1. Encodes the input values to a `[String: Any]` dictionary using `DictionaryEncoder`.
    /// 2. Converts dictionary keys according to the ``caseType`` setting.
    /// 3. For each field:
    ///    - Appends simple values as text.
    ///    - Appends file data for `Data` or `[Data]` values.
    /// 4. Closes the payload with a terminating boundary marker.
    ///
    /// - Parameter values: An `Encodable & Sendable` type containing the form fields and file URLs.
    /// - Returns: A `Data` object representing the multipart body.
    /// - Throws: Any error thrown during encoding or file reading.
    func generateFormData<T: Encodable & Sendable>(_ values: T) throws -> Data {
        var data = Data()
        
        let encoder = DictionaryEncoder()
        try values.encode(to: encoder)
        
        for (key, value) in encoder.storage.dict {
            let name = caseType.convert(key)
            
            if let builtData = try buildData(name: name, value: value){
                data.append(builtData)
            }
        }
        
        data.append("--\(boundary)--\r\n")
        
        return data
    }
    
    // MARK: - Internal Helpers
    
    /// Creates a formatted multipart boundary line for a field or file.
    ///
    /// - Parameters:
    ///   - name: The field name.
    ///   - filename: Optional filename (for file uploads).
    ///   - mimeType: Optional MIME type (for file uploads).
    /// - Returns: A correctly formatted multipart section header.
    private func boundaryLine(
        name: String,
        filename: String? = nil,
        mimeType: String? = nil
    ) -> String {
        var line = "--\(boundary)\r\n"
        line += "Content-Disposition: form-data; name=\"\(name)\""
        if let filename = filename { line += "; filename=\"\(filename)\"" }
        line += "\r\n"
        if let mimeType = mimeType { line += "Content-Type: \(mimeType)\r\n" }
        line += "\r\n"
        return line
    }
    
    /// Builds a multipart section for the given field name and value.
    ///
    /// This method inspects the type of `value` to decide how it should be encoded:
    /// - If the value is a single `Data` object, it is treated as a file.
    /// - If the value is an array of `Data`, each element is treated as a separate file
    ///   under the same field name.
    /// - Otherwise, the value is converted to a string and treated as a simple text field.
    ///
    /// - Parameters:
    ///   - name: The field name associated with the value.
    ///   - value: The value to encode. Can be `Data`, `[Data]`, or any other type convertible to `String`.
    /// - Returns: A `Data` object representing the multipart section for the given value.
    /// - Throws: `MultiPartError.emptyData` if a file or array of files is empty.
    ///
    /// - Note:
    ///   This method automatically appends boundary markers and line breaks as required
    ///   by the multipart/form-data specification.
    private func buildData(name: String, value: Any) throws -> Data? {
        var data = Data()
        
        if let file = value as? Data {
            guard !file.isEmpty else { return nil }
            data.append(getFileData(name: name, file: file))
        } else if let files = value as? [Data] {
            guard !files.isEmpty else { throw MultiPartError.emptyArray }
            for file in files {
                guard !file.isEmpty else { return nil }
                data.append(getFileData(name: name, file: file))
            }
        } else {
            data.append(boundaryLine(name: name))
            data.append(Utils.anyToString(value))
            data.append("\r\n")
        }
        
        return data
    }
    
    
    /// Creates a multipart section for a single file upload.
    ///
    /// - Parameters:
    ///   - name: The field name associated with the file.
    ///   - file: The file contents as raw `Data`.
    /// - Returns: A `Data` object representing the multipart section for the file.
    ///            Includes boundary, content disposition, MIME type, and file contents.
    ///
    /// - Note:
    ///   - The file’s MIME type and extension are automatically detected using `detectFileType(from:)`.
    ///   - The filename is generated randomly to avoid collisions, using `Utils.randomHexString()`.
    private func getFileData(name: String, file: Data) -> Data {
        var data = Data()
        let fileType = detectFileType(from: file)
        let filename = Utils.randomHexString() + "." + fileType.ext
        
        let boundaryLine = self.boundaryLine(
            name: name, filename: filename, mimeType: fileType.mime
        )
        data.append(boundaryLine)
        data.append(file)
        data.append("\r\n")
        
        return data
    }
}

// MARK: - Handle Mime Type
extension MultiPartBuilder {
    /// Detect a MIME type from raw bytes.
    private func detectMimeType(data: Data) -> String {
        let b = [UInt8](data.prefix(512))

        func has(_ sig: [UInt8], at off: Int = 0) -> Bool {
            guard b.count >= off + sig.count else { return false }
            return b[off ..< off + sig.count].elementsEqual(sig)
        }

        // --- Images ---
        if has([0xFF, 0xD8]) { return "image/jpeg" }
        if has([0x89, 0x50, 0x4E, 0x47]) { return "image/png" }            // PNG
        if has([0x47, 0x49, 0x46, 0x38]) { return "image/gif" }            // GIF
        if has([0x42, 0x4D]) { return "image/bmp" }                        // BMP
        if has([0x49, 0x49, 0x2A, 0x00]) || has([0x4D, 0x4D, 0x00, 0x2A]) { return "image/tiff" }
        // RIFF containers: WEBP / WAV / AVI
        if has([0x52, 0x49, 0x46, 0x46]) && b.count >= 12 {
            if has([0x57, 0x45, 0x42, 0x50], at: 8) { return "image/webp" }
            if has([0x57, 0x41, 0x56, 0x45], at: 8) { return "audio/wav" }
            if has([0x41, 0x56, 0x49, 0x20], at: 8) { return "video/x-msvideo" }
        }
        // ISO BMFF (mp4/m4a/3gp/heic/avif…): .... 'ftyp' BRAND
        if b.count >= 12 && b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70 {
            let brand = String(bytes: b[8..<12], encoding: .ascii) ?? ""
            switch brand {
            case "M4A ": return "audio/mp4"
            case "avif", "avis": return "image/avif"
            case "heic", "heif": return "image/heic"
            default: return "video/mp4"    // isom, mp41, mp42, 3gp*, etc.
            }
        }

        // --- Documents / archives ---
        if has([0x25, 0x50, 0x44, 0x46]) { return "application/pdf" }      // %PDF
        if has([0x50, 0x4B, 0x03, 0x04]) { return "application/zip" }      // ZIP / docx/xlsx/etc
        if has([0x1F, 0x8B]) { return "application/gzip" }                 // GZIP
        if has([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) { return "application/x-7z-compressed" }
        if has([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]) { return "application/x-rar-compressed" }

        // --- Audio ---
        if has([0x49, 0x44, 0x33]) || (b.count >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
            return "audio/mpeg" // MP3 (ID3 header or MPEG frame sync)
        }
        if has([0x66, 0x4C, 0x61, 0x43]) { return "audio/flac" }           // fLaC
        if has([0x4F, 0x67, 0x67, 0x53]) { return "audio/ogg" }            // OggS

        // --- WebM / Matroska ---
        if has([0x1A, 0x45, 0xDF, 0xA3]) { return "video/webm" }
        
        // --- XML detection ---
        if let str = String(data: data.prefix(100), encoding: .utf8),
           str.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<?xml") {
            return "application/xml"
        }

        // --- Text heuristics (last resort) ---
        if let s = String(data: data.prefix(4096), encoding: .utf8) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                // JSON
                if t.hasPrefix("{") || t.hasPrefix("[") {
                    return "application/json"
                }

                // Markdown heuristic: plain text that contains Markdown cues
                if t.contains("# ") || t.contains("```") || t.contains("* ") || t.contains("[") && t.contains("](") {
                    return "text/markdown"
                }

                return "text/plain"
        }

        return "application/octet-stream" // unknown binary
    }

    /// Convert detected MIME to UTType (falls back to .data).
    private func inferUTType(from data: Data) -> UTType {
        let mime = detectMimeType(data: data)
        return UTType(mimeType: mime) ?? .data
    }

    /// Convenience that also gives an file extension.
    private struct DetectedType {
        let utType: UTType
        var mime: String { utType.preferredMIMEType ?? "application/octet-stream" }
        var ext: String { utType.preferredFilenameExtension ?? "bin" }
    }

    private func detectFileType(from data: Data) -> DetectedType {
        let ut = inferUTType(from: data)
        return DetectedType(utType: ut)
    }
}
