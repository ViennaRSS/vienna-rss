//
//  SecurityScopedBookmark.swift
//  Vienna
//
//  Copyright 2017-2019, 2021, 2023 Eitot
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import os.log

/// Creates a security-scoped bookmark to access files outside of the sandbox in
/// response to user selection via `NSOpenPanel`.
///
/// A bookmark is created either with `init(fileURL:)`, which will also resolve
/// the bookmark into a URL, or `bookmarkData(from:)`. To resolve a URL from
/// bookmark data, use `init(bookmarkData:bookmarkDataIsStale:)`.
@objc(VNASecurityScopedBookmark)
class SecurityScopedBookmark: NSObject {

    // MARK: Initialization

    /// The URL of the scoped bookmark.
    @objc let resolvedURL: URL

    /// The data of the scoped bookmark.
    let bookmarkData: Data

    /// Creates a security-scoped bookmark from the given data.
    ///
    /// - Parameters:
    ///   - data: The bookmark data that was previously created.
    ///   - bookmarkDataIsStale: Indicates that the bookmark data should be
    ///       refreshed, e.g. with `bookmarkData(from:)`.
    /// - Note: Fails when the stored bookmark cannot be created with the given
    ///     data or the bookmark cannot be resolved into a URL.
    @objc
    init(bookmarkData data: Data, bookmarkDataIsStale: UnsafeMutablePointer<Bool>?) throws {
        bookmarkData = data
        var isStale = false
        resolvedURL = try SecurityScopedBookmark.resolveBookmarkData(bookmarkData,
                                                                     bookmarkDataIsStale: &isStale)
        bookmarkDataIsStale?.pointee = isStale

        // If `startAccessingSecurityScopedResource()` returns `true` then that
        // call must be balanced out by `stopAccessingSecurityScopedResource()`.
        // This is implemented in `deinit`. Therefore, if `false` is returned,
        // the initialization should fail.
        guard resolvedURL.startAccessingSecurityScopedResource() else {
            os_log("Unable to start accessing bookmarked URL", log: .bookmark, type: .error)
            throw SecurityScopedBookmarkError.bookmarkNotAccessed
        }
    }

    /// Creates a security-scoped bookmark from the given file URL.
    ///
    /// - Parameter fileURL: The URL for which to create a bookmark.
    /// - Note: Fails when the stored bookmark cannot be created with the given
    ///     URL or the bookmark cannot be resolved into a URL.
    convenience init(fileURL url: URL) throws {
        let bookmarkData = try SecurityScopedBookmark.bookmarkData(from: url)
        // `bookmarkDataIsStale` should not return `true`, as the data is fresh.
        try self.init(bookmarkData: bookmarkData, bookmarkDataIsStale: nil)
    }

    deinit {
        resolvedURL.stopAccessingSecurityScopedResource()
    }

    // MARK: Creating and resolving bookmarks

    /// Creates bookmark data from the given URL.
    ///
    /// - Parameter fileURL: The URL for which to create a bookmark.
    /// - Returns: An object containing the bookmark data.
    /// - Note: Fails when the bookmark cannot be created with the given URL or
    ///     the bookmark cannot be resolved into a URL.
    @objc(bookmarkDataFromFileURL:error:)
    static func bookmarkData(from fileURL: URL) throws -> Data {
        do {
            let data = try fileURL.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            return data
        } catch let error as CocoaError where error.code == .fileReadUnknown {
            let desc = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? "unknown"
            os_log("Unable to create bookmark. Reason: %@", log: .bookmark, type: .fault, desc)
            throw error
        } catch {
            os_log("Unable to create bookmark with unhandled error", log: .bookmark, type: .fault)
            throw error
        }
    }

    private static func resolveBookmarkData(_ bookmarkData: Data, bookmarkDataIsStale isStale: inout Bool) throws -> URL {
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            return url
        } catch let error as CocoaError where error.code == .fileReadUnknown {
            let desc = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? "unknown"
            os_log("Unable to resolve bookmark. Reason: %@", log: .bookmark, type: .fault, desc)
            throw error
        } catch {
            os_log("Unable to resolve bookmark with unhandled error", log: .bookmark, type: .fault)
            throw error
        }
    }

    // MARK: Error handling

    enum SecurityScopedBookmarkError: Int, Error {
        case bookmarkNotAccessed
    }

}

// MARK: - Private extensions

private extension OSLog {

    static let bookmark = OSLog(subsystem: "--", category: "SecurityScopedBookmark")

}
