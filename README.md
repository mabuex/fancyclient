# FancyClient

&#x20;&#x20;

A type-safe, leight-weight, Swift-native HTTP client for building requests, handling query parameters, JSON bodies, multipart, and downloads. Supports iOS, macOS, tvOS, watchOS, and visionOS.

---

## Features

- Type-safe API endpoints
- Query builder for strongly-typed or dictionary queries
- JSON-encoded request bodies
- Multipart form data support with file uploads
- Async/await support for Swift concurrency
- Thread-safe (`Sendable`) client usage

---

## Requirements

- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+ / visionOS 1.0+
- Xcode 16.2+
- Swift 5.10+

---

## Installation

Add FancyClient via Swift Package Manager:

```swift
let package = Package(
    ...
    dependencies: [
        ...
        .package(
            url: "https://github.com/mabuex/fancyclient.git",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "YourTargetName",
            dependencies: [
                .product(name: "FancyClient", package: "fancyclient")
            ]
        )
    ]
)
```

---

## Quick Start

```swift
import Foundation
import FancyClient

// Define your API endpoints
enum ApiEndpoints: Endpoint {
    case me
    case users(Int? = nil)
    case products(Int? = nil, path: String? = nil)
    case upload
    case download(path: String)
    case chat(_ roomId: String)
    
    var path: String {
        switch self {
        case .me: return "/me"
        case .users(let id): return id.map { "/users/\($0)" } ?? "/users"
        case .products(let id, let path):
            switch (id, path) {
            case let (id?, path?): return "/products/\(id)/\(path)"
            case let (id?, nil): return "/products/\(id)"
            case let (nil, path?): return "/products/\(path)"
            default: return "/products"
            }
        case .upload: return "/upload"
        case .download(let path): return "/download/\(path)"
        case .chat(let roomId): "/rooms/\(roomId)"
        }
    }

    var headers: HeaderFields { ["Content-Type": "application/json"] }
}

// Initialize the client
let client = Client<ApiEndpoints>(baseUrl: URL(string: "https://your-api.com/api/v1")!)

// Example: GET users
struct User: Codable & Sendable {
    let id: Int
    let username: String
}

func getAllUsers() async throws -> [User] {
    try await client.endpoint(.users()).get().execute()
}

// Example: POST new user
struct AddUpdateUserRequest: Codable & Sendable {
    let username: String
}

func addUser(addUser: AddUpdateUserRequest) async throws -> User {
    try await client.endpoint(.users()).post(addUser).execute()
}

// Example: Multipart form upload
struct UploadForm: Encodable & Sendable {
    let image: Data
    let name: String
    let age: Int
}

struct UploadResponse: Decodable & Sendable {
    let message: String
}

func uploadFormData(image: Data, name: String, age: Int) async throws -> UploadResponse {
    let form = UploadForm(image: image, name: name, age: age)
    return try await client.endpoint(.upload).post(multipart: form).execute()
}

// Example: Query parameters
func filterProductsByPrice(min: Double, max: Double) async throws -> [Product] {
    try await client.endpoint(.products(path: "filter"))
              .get()
              .query(["min_price": min, "max_price": max])
              .execute()
}

// Example: Download a file
func download(_ path: String) async throws {
    let downloadTask = try await client
        .endpoint(.download(path: path))
        .download()
        .execute { events in
            for await event in events {
                switch event {
                case let .progress(current, total):
                    print("📈 Progress:", current, "/", total)
                case let .paused(data):
                    print("⏸️ Paused, resume data:", data.count)
                case let .completed(url):
                    print("✅ Saved to:", url)
                case let .failed(error):
                    print("❌ Failed:", error.localizedDescription)
                case let .canceled(data):
                    print("❌ Canceled, partial bytes:", data?.count ?? 0)
                }
            }
        }
}

// ⚠️ Experimental
// Example: Connect to a WebSocket
func connect(for roomId: String) async {
    let stream = client.endpoint(.chat(roomId)).socket().stream()
    
    await stream.connect()
    
    do {
        for try await event in stream {
            switch event {
            case .connected:
                print("Connected ✅")
            case .text(let text):
                print("Message:", text)
            case .disconnected(let error):
                print("Closed ❌", error ?? "")
            default: break
            }
        }
    } catch {
        print(error.localizedDescription)
    }
}

func sendMessage(_ text: String) async {
    do {
        try await stream?.send(text)
    } catch {
        print("Failed to send message:", error.localizedDescription)
    }
}

func disconnect() async {
    await stream?.disconnect()
}

```

---

## Initialize with custom configuration

```swift
// Custom formatter for Date
var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "ko_kr")
    formatter.timeZone = TimeZone(abbreviation: "KST")
    return formatter
}

let customEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(dateFormatter)
    return encoder
}()

let customDecoder = { () -> JSONDecoder in
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    decoder.dateDecodingStrategy = .formatted(dateFormatter)
    return decoder
}()

let customSessionConfig = { () -> URLSessionConfiguration in
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.httpShouldSetCookies = false
    config.httpCookieAcceptPolicy = .never
    return config
}()

let client = Client<ApiEndpoints>(
    baseUrl: URL(string: "https://your-api.com/api/v1")!,
    encoder: customEncoder,
    decoder: customDecoder,
    sessionConfig: customSessionConfig,
    defaultCaseType: .kebabCase, // Forms and queries
    debug: true
)

```

---

## Usage Notes

- **Thread Safety:** All requests are `Sendable` and can be safely used in concurrent Swift tasks.
- **Custom Encoding/Decoding:** You can provide your own `JSONEncoder` and `JSONDecoder` for custom serialization.
- **Multipart Uploads:** Use `Data` for single file or `[Data]` for multiple files in forms.
- **Query Parameters:** Supports both `Encodable` structs and plain dictionaries.

---

## License

MIT License

Copyright (c) 2025 Marcus Buexenstein

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
