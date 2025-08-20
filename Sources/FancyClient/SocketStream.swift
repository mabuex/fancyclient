//
//  SocketStream.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/19/25.
//

import Foundation

/// An actor-based WebSocket client with built-in reconnect, keep-alive ping,
/// and async event streaming.
///
/// `SocketStream` wraps `URLSessionWebSocketTask` to provide:
/// - **Safe concurrency** (isolated via Swift `actor`)
/// - **AsyncThrowingStream** of connection events (`.connected`, `.disconnected`, `.reconnecting`, `.text`, `.data`)
/// - **Automatic reconnect** with capped exponential backoff and jitter
/// - **Simple send APIs** for text, binary, and JSON-encodable messages
/// - **Configurable keep-alive ping loop**
///
/// ## Usage
///
/// ```swift
/// let request = URLRequest(url: URL(string: "wss://echo.websocket.events")!)
/// let config = URLSessionConfiguration.default
///
/// let socket = SocketStream(request: request, config: config)
///
/// Task {
///     await socket.connect()
/// }
///
/// Task {
///     do {
///         for try await event in socket {
///             switch event {
///             case .connected:
///                 print("Connected ✅")
///                 try? await socket.send("Hello!")
///             case .text(let text):
///                 print("Received:", text)
///             case .reconnecting(let attempt):
///                 print("Reconnecting attempt:", attempt)
///             case .disconnected(let error):
///                 print("Disconnected ❌", error ?? "")
///             default: break
///             }
///         }
///     } catch {
///         print("Stream ended with error:", error)
///     }
/// }
/// ```
///
/// ## Reconnect Strategy
/// - When a connection drops with an error, `SocketStream` automatically attempts
///   to reconnect if `disconnect()` has not been called.
/// - Reconnects use **exponential backoff with jitter**:
///   - 1st retry after ~2s (+ random jitter 0–1s)
///   - 2nd retry after ~4s (+ jitter)
///   - 3rd retry after ~8s (+ jitter)
///   - … doubling each attempt
/// - Delays are capped at **30 seconds maximum**.
/// - Each attempt emits `.reconnecting(Int)` with the attempt count (starting at 1).
/// - **The async stream continues across reconnects**, so iteration does not end
///   on disconnects; new events are emitted when the socket reconnects.
/// - If `maxReconnectAttempts` is set and exceeded, the stream is finished with
///   an error (`URLError.cannotConnectToHost`).
///
/// ## Ping Strategy
/// - By default, no pings are sent until `connect()` starts a background ping loop.
/// - The loop sends a `ping` frame every `pingInterval` seconds.
/// - If a ping fails, `.disconnected(error)` is emitted and a reconnect attempt begins.
/// - Many servers close idle sockets after ~30 seconds; a 25s default interval is recommended.
///
/// ## Notes
/// - Call `connect()` once before iterating the stream (idempotent).
/// - Call `disconnect()` to close the socket and stop reconnects.
/// - Use `send<T: Encodable>(_:)` to automatically encode Swift types to JSON before sending.
public actor SocketStream: AsyncSequence {
    public typealias Element = StreamEvent
    public typealias AsyncIterator = AsyncThrowingStream<Element, Error>.Iterator
    
    /// Lifecycle and message events emitted by `SocketStream`.
    public enum StreamEvent: Sendable {
        /// Socket successfully connected.
        case connected
        /// Socket closed or failed, with optional error.
        case disconnected(Error?)
        /// Text message received from the server.
        case text(String)
        /// Binary message received from the server.
        case data(Data)
        /// Socket is attempting to reconnect (provides attempt count).
        case reconnecting(Int)
    }
    
    // MARK: Identity
    
    /// Unique identifier for this connection.
    public nonisolated let id = UUID()
    
    // MARK: Configurable
    
    /// Interval in seconds between keep-alive pings.
    private let pingInterval: TimeInterval
    /// Maximum reconnect attempts before failing permanently. `nil` = unlimited.
    private let maxReconnectAttempts: Int?
    
    // MARK: Private state
    
    /// Underlying event stream.
    private let stream: AsyncThrowingStream<StreamEvent, Error>
    /// Handle for yielding into the stream.
    private let continuation: AsyncThrowingStream<Element, Error>.Continuation
    
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var isActive: Bool = false
    private var reconnectAttempts = 0
    
    private var listenerTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    
    // MARK: Init
    
    /// Creates a new `SocketStream` for the given request and configuration.
    ///
    /// - Parameters:
    ///   - request: A `URLRequest` configured for WebSocket use.
    ///   - config: A `URLSessionConfiguration` used to create the session.
    ///   - pingInterval: Interval in seconds between keep-alive pings (default: 25).
    ///   - maxReconnectAttempts: Optional maximum number of reconnect attempts before failing.
    ///
    /// - Note: Prefer calling `connect()` before iterating the stream.
    init(
        request: URLRequest,
        config: URLSessionConfiguration,
        pingInterval: TimeInterval = 25,
        maxReconnectAttempts: Int? = nil
    ) {
        self.session = URLSession(configuration: config)
        self.task = session?.webSocketTask(with: request)
        self.pingInterval = pingInterval
        self.maxReconnectAttempts = maxReconnectAttempts
        
        (stream, continuation) = AsyncThrowingStream.makeStream(of: StreamEvent.self)
        
        continuation.onTermination = { [weak self] _ in
            Task { await self?.disconnect() }
        }
    }
    
    // MARK: AsyncSequence
    
    public nonisolated func makeAsyncIterator() -> AsyncIterator {
        stream.makeAsyncIterator()
    }
    
    // MARK: Controls
    
    // MARK: Connect / Disconnect
    public func connect() async {
        guard !isActive else { return } // idempotent
        isActive = true
        reconnectAttempts = 0
        
        task?.resume()
        continuation.yield(.connected)
        
        startListener()
        startPingLoop()
    }
    
    /// Closes the WebSocket connection and stops reconnect attempts.
    public func disconnect() async {
        isActive = false
        listenerTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        continuation.finish()
    }
    
    /// Sends a UTF-8 text message over the WebSocket.
    /// - Parameter text: The string to send.
    public func send(_ text: String) async throws {
        try await task?.send(.string(text))
    }
    
    /// Sends binary data over the WebSocket.
    /// - Parameter data: The raw bytes to send.
    public func send(_ data: Data) async throws {
        try await task?.send(.data(data))
    }
    
    public func send<T: Encodable>(_ value: T) async throws {
        let data = try JSONEncoder().encode(value)
        try await send(data)
    }
    
    /// Starts a background keep-alive loop that sends periodic pings.
    /// - Parameter interval: Time in seconds between pings (default: 25).
    /// - Note: Many servers close idle sockets after ~30s without activity.
    private func startPingLoop() {
        // cancel old ping loop if running
        pingTask?.cancel()
        
        pingTask = Task { [weak self] in
            guard let self else { return }
            
            while await self.isActive {
                try? await Task.sleep(for: .seconds(pingInterval))
                
                await task?.sendPing { [weak self] error in
                    guard let self else { return }
                    if let error {
                        continuation.yield(.disconnected(error))
                        
                        Task {
                            await self.disconnect()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Private listening & reconnect
    
    private func startListener() {
        listenerTask?.cancel()
        listenerTask = Task { [weak self] in
            guard let self else { return }
            while await isActive {
                await listen()
            }
        }
    }
    
    private func listen() async {
        do {
            guard let message = try await task?.receive() else { return }
            
            switch message {
            case .string(let text):
                continuation.yield(.text(text))
            case .data(let data):
                continuation.yield(.data(data))
            @unknown default:
                break
            }
        } catch {
            continuation.yield(.disconnected(error))
            await reconnect()
        }
    }
    
    private func reconnect() async {
        guard isActive else { return }
        reconnectAttempts += 1
        
        if let max = maxReconnectAttempts, reconnectAttempts > max {
            continuation.finish(throwing: URLError(.cannotConnectToHost))
            return
        }
        
        let jitter = Double.random(in: 0...1.0)
        let delay = Swift.min(2.0 * pow(2.0, Double(reconnectAttempts - 1)) + jitter, 30.0)
        
        continuation.yield(.reconnecting(reconnectAttempts))
        
        try? await Task.sleep(for: .seconds(Int(delay)))
        task?.resume()
    }
}
