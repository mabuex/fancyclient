//
//  DownloadBuilder.swift
//  FancyClient
//
//  Created by Marcus Buexenstein on 8/14/25.
//

import Foundation

/// A builder class for constructing download requests with query parameters.
///
/// Conforms to `QueryBuilder` to provide functionality for encoding `Encodable` objects
/// into URL query items. Marked as `@unchecked Sendable` to allow safe usage across
/// concurrent contexts, though internal state is protected by a lock.
public class DownloadBuilder: BaseBuilder, QueryBuilder, @unchecked Sendable {
    
    // MARK: - Public Methods
    
    /// Attaches a query parameter object to the request being built.
    ///
    /// - Parameters:
    ///   - query: A type conforming to both `Encodable` and `Sendable`
    ///            representing the query parameters.
    ///   - caseType: The key casing style for query parameter names.
    ///               Defaults to the builder's configured case type.
    /// - Returns: The same ``DownloadBuilder`` instance for method chaining.
    /// - Throws: Any error thrown while encoding the query object.
    public func query(_ query: Encodable & Sendable, caseType: CaseType? = nil) throws -> Self {
        resource.query = try getQueryItems(query, caseType: caseType ?? config.caseType)
        return self
    }
    
    /// Starts a download task for the specified resource and streams progress updates.
    ///
    /// This function performs an asynchronous download using the `DownloadTask` class.
    /// It returns a reference to the active `DownloadTask` instance, which allows external
    /// control for pausing, resuming, or canceling the download.
    ///
    /// The function reports progress updates via the provided `completion` closure.
    ///
    /// - Parameter completion: A closure that receives periodic progress updates
    ///   with the number of bytes downloaded (`currentBytes`) and the total bytes
    ///   expected (`totalBytes`).
    ///
    /// - Returns: The active `DownloadTask` instance for controlling pause, resume, or cancel.
    ///
    /// - Throws: An error if the download fails.
    public func execute(
        completion: ((AsyncStream<DownloadTask.StreamEvent>) async -> Void)? = nil
    ) async throws -> DownloadTask {
        // Initialize the Download object
        let downloadTask = await DownloadTask.make(
            request: baseRequest,
            destinationFolder: config.destinationFolder,
            config: sessionConfig
        )
        
        // Start the download task
        await downloadTask.start()
        
        if let completion {
            await completion(downloadTask.events)
        }
        
        // Return the Download instance to allow external control
        return downloadTask
    }
}
