//
//  DownloadTask.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/16/25.
//

import Foundation

// MARK: - Actor

/// A resumable, progress-reporting download built on `URLSession`.
///
/// Consume `events` (an `AsyncStream`) for `.progress` updates and one terminal event:
/// `.completed`, `.failed`, or `.canceled`. The stream finishes after a terminal event.
///
/// Usage:
///   - Create with `init(destinationFolder:)`
///   - Call `await configure(request:)` to build the session + task
///   - `await start()` to begin
///   - `await pause()` → emits `.paused(resumeData:)`
///   - `await resume(with:)` to continue later
///
/// Success is reported **only after** verifying an HTTP 2xx status and successfully
/// moving the temp file into `Documents/<destinationFolder>/...`.
public actor DownloadTask: Identifiable {
    
    // MARK: Events
    
    /// Events emitted by the download.
    ///
    /// Lifecycle:
    /// - `.progress` is emitted during transfer
    /// - Terminal: `.completed`, `.failed`, `.canceled`
    /// - The stream ends after a terminal event
    public enum StreamEvent: Sendable {
        case progress(currentBytes: Int64, totalBytes: Int64)
        case completed(url: URL)
        case paused(resumeData: Data)
        case canceled(data: Data?)
        case failed(Error)
    }
    
    // MARK: Errors
    
    public enum DownloadTaskError: Error, LocalizedError, Sendable {
        case invalidStatusCode(Int)
        case missingTemporaryFile
        case failedToSaveFile(Error)
        case failedToMoveFile(Error)
        case missingDestination
        case resumeNotAvailable
        
        public var errorDescription: String? {
            switch self {
            case .invalidStatusCode(let code):
                return "Invalid HTTP response with status code: \(code)."
            case .missingTemporaryFile:
                return "Temporary downloaded file URL is missing."
            case .failedToSaveFile(let error):
                return "Failed to save the file: \(error.localizedDescription)"
            case .failedToMoveFile(let error):
                return "Failed to move the file: \(error.localizedDescription)"
            case .missingDestination:
                return "Destination folder was not provided."
            case .resumeNotAvailable:
                return "No resume data is available to resume the download."
            }
        }
    }
    
    // MARK: Identity
    
    public nonisolated let id = UUID()
    
    // MARK: Public state
    
    /// Final saved file URL after completion.
    public private(set) var savedURL: URL?
    
    /// Resume data produced by `pause()`.
    public private(set) var resumeData: Data?
    
    /// Stream of download events.
    public let events: AsyncStream<StreamEvent>
    
    // MARK: Private state
    
    private let destinationFolder: String
    private let continuation: AsyncStream<StreamEvent>.Continuation
    
    private var session: URLSession?
    private var delegate: SessionDelegate?  // keep a strong reference
    private var task: URLSessionDownloadTask?
    
    private var isFinished = false
    
    // MARK: Init (non-isolated)
    
    /// Minimal initializer. Does *not* touch session/task to satisfy actor init rules.
    /// - Parameter destinationFolder: Subfolder inside Documents where the file will be moved.
    public init(destinationFolder: String) {
        self.destinationFolder = destinationFolder
        (events, continuation) = AsyncStream.makeStream(of: StreamEvent.self)
    }
    
    // MARK: Configuration (actor-isolated)
    
    /// Second phase: build the session + task. Call this **before** `start()`.
    /// - Parameters:
    ///   - request: The URLRequest to download.
    ///   - cookieStorage: Cookie storage to use (default `.shared`).
    public func configure(
        request: URLRequest,
        config: URLSessionConfiguration,
        cookieStorage: HTTPCookieStorage
    ) {
        // Bridge URLSession delegate → actor via a small forwarding object.
        let delegate = SessionDelegate(destinationFolder) { [weak self] event in
            guard let self else { return }
            Task { await self.handleDelegateEvent(event) }
        }
        self.delegate = delegate
        
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        self.session = session
        self.task = session.downloadTask(with: request)
        
        // If the consumer stops iterating the stream, we cancel the task.
        continuation.onTermination = { [weak self] _ in
            Task { await self?.cancel() }
        }
    }
    
    // Convenience factory:
    public static func make(
        request: URLRequest,
        destinationFolder: String,
        config: URLSessionConfiguration,
        cookieStorage: HTTPCookieStorage = .shared
    ) async -> DownloadTask {
        let instance = DownloadTask(destinationFolder: destinationFolder)
        await instance.configure(request: request, config: config, cookieStorage: cookieStorage)
        return instance
    }
    
    // MARK: Controls (actor-isolated)
    
    /// Starts (or resumes) the download.
    public func start() {
        task?.resume()
    }
    
    /// Pauses the download and emits `.paused(resumeData:)` if available.
    public func pause() {
        task?.cancel { [weak self] data in
            guard let self else { return }
            Task { await self.setResumeDataAndEmit(data) }
        }
    }
    
    /// Resumes from resume data (from parameter or previously stored).
    public func resume(with data: Data? = nil) {
        let dataToUse = data ?? resumeData
        guard let dataToUse else {
            emitOnce(.failed(DownloadTaskError.resumeNotAvailable))
            return
        }
        // Reset transient state
        resumeData = nil
        
        if let session {
            task = session.downloadTask(withResumeData: dataToUse)
            task?.resume()
        }
    }
    
    /// Cancels the download and emits `.canceled`.
    public func cancel() {
        task?.cancel { [weak self] data in
            guard let self else { return }
            Task { await self.emitOnce(.canceled(data: data)) }
        }
    }
    
    // MARK: Delegate event handling
    
    private func handleDelegateEvent(_ event: SessionDelegate.SinkEvent) {
        switch event {
        case let .progress(written, expected):
            continuation.yield(.progress(currentBytes: written, totalBytes: expected))
            
        case let .didFinishSuccessfully(finalURL):
            emitOnce(.completed(url: finalURL))
            
        case let .didComplete(error, response):
            // Terminal path
            if let error {
                emitOnce(.failed(error))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                emitOnce(.failed(DownloadTaskError.invalidStatusCode(-1)))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                emitOnce(.failed(DownloadTaskError.invalidStatusCode(http.statusCode)))
                return
            }
            
        case .didFailDuringMove(error: let error):
            emitOnce(.failed(DownloadTaskError.failedToMoveFile(error)))
        }
    }
    
    private func setResumeDataAndEmit(_ data: Data?) {
        guard let data else { return }
        self.resumeData = data
        continuation.yield(.paused(resumeData: data))
    }
    
    /// Emit a terminal event exactly once and finish the stream.
    private func emitOnce(_ event: StreamEvent) {
        guard !isFinished else { return }
        isFinished = true
        continuation.yield(event)
        continuation.finish()
    }
}

// MARK: - URLSession Delegate Bridge

/// Lightweight delegate that forwards URLSession events to the actor via a @Sendable closure.
private final class SessionDelegate: NSObject, URLSessionDownloadDelegate {
    enum SinkEvent: Sendable {
        case progress(written: Int64, expected: Int64)
        case didFinishSuccessfully(finalURL: URL)
        case didFailDuringMove(error: Error)
        case didComplete(error: Error?, response: URLResponse?)
    }
    
    private let destination: String
    private let sink: @Sendable (SinkEvent) -> Void
    
    
    init(_ destination: String, sink: @escaping @Sendable (SinkEvent) -> Void) {
        self.destination = destination
        self.sink = sink
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        sink(.progress(written: totalBytesWritten, expected: totalBytesExpectedToWrite))
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Pick suggested filename or fallback
        let suggested = downloadTask.response?.suggestedFilename
        
        do {
            let finalURL = try saveFile(at: location, suggestedFilename: suggested)
            sink(.didFinishSuccessfully(finalURL: finalURL))
        } catch {
            sink(. didFailDuringMove(error: error))
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        sink(.didComplete(error: error, response: task.response))
    }
    
    /// Moves a downloaded temporary file to a permanent location inside the app's Documents directory.
    ///
    /// This function ensures the target download folder exists, preserves the file extension,
    /// removes any existing file with the same name, and moves the temporary file to the permanent location.
    ///
    /// - Parameter tempURL: The temporary file URL provided by `URLSessionDownloadTask`.
    /// - Returns: The final permanent URL where the file has been saved.
    /// - Throws: Throws an error if the file cannot be moved or if directory creation fails.
    private func saveFile(at tempURL: URL, suggestedFilename: String?) throws -> URL {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderURL = documents.appendingPathComponent(destination, isDirectory: true)
        
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let fileName: String = suggestedFilename ?? {
            let base = tempURL.deletingPathExtension().lastPathComponent
            let ext  = tempURL.pathExtension
            return ext.isEmpty ? base : "\(base).\(ext)"
        }()
        
        let destinationURL = folderURL.appendingPathComponent(fileName)
        
        // Remove old file if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
}
