//
//  SecurityScopedBookmark.swift
//  Vienna
//
//  Copyright 2017-2019, 2021 Eitot
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
/// A bookmark is created either with `init(url:)`, which will also resolve the
/// bookmark into a URL, or `bookmark(_:)`. To resolve a URL from bookmark data,
/// use `init(bookmarkData:)`.
@objc(VNASecurityScopedBookmark)
final class SecurityScopedBookmark: NSObject {

    // MARK: Initialization

    /// The URL of the scoped bookmark.
    @objc let resolvedURL: URL

    /// The data of the scoped bookmark.
    @objc let bookmarkData: Data

    private var accessed: Bool

    /// Creates a security-scoped bookmark from the given URL.
    ///
    /// - Parameter url: The URL to create a bookmark for.
    /// - Note: Fails when the stored bookmark cannot be created with the given
    ///     URL or the bookmark cannot be resolved into a URL.
    @objc
    init(url: URL) throws {
        bookmarkData = try SecurityScopedBookmark.bookmark(url)
        resolvedURL = try SecurityScopedBookmark.resolve(bookmarkData)

        // It is undocumented whether the return value indicates an error.
        accessed = resolvedURL.startAccessingSecurityScopedResource()
        if !accessed {
            os_log("Access request for resolved URL returned false", log: .bookmark, type: .fault)
        }
    }

    /// Creates a security-scoped bookmark from the given data.
    ///
    /// - Parameter data: The bookmark data that was previously created.
    /// - Note: Fails when the stored bookmark cannot be created with the given
    ///     data or the bookmark cannot be resolved into a URL.
    @objc
    init(bookmarkData data: Data) throws {
        bookmarkData = data
        resolvedURL = try SecurityScopedBookmark.resolve(bookmarkData)

        // It is undocumented whether the return value indicates an error.
        accessed = resolvedURL.startAccessingSecurityScopedResource()
        if !accessed {
            os_log("Access request for resolved URL returned false", log: .bookmark, type: .fault)
        }
    }

    deinit {
        if accessed {
            resolvedURL.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: Creating and resolving bookmarks

    /// Creates bookmark data from the given URL.
    ///
    /// - Parameter data: The URL to create a bookmark for.
    /// - Returns: An object containing the bookmark data.
    /// - Note: Fails when the bookmark cannot be created with the given URL or
    ///     the bookmark cannot be resolved into a URL.
    @objc
    static func bookmark(_ url: URL) throws -> Data {
        let data: Data
        do {
            data = try url.bookmarkData(options: .withSecurityScope,
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil)
        } catch let error as CocoaError where error.code == .fileReadUnknown {
            let desc = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? "unknown"
            os_log("Unable to create bookmark. Reason: %@", log: .bookmark, type: .fault, desc)
            throw error
        } catch {
            os_log("Unable to create bookmark with unhandled error", log: .bookmark, type: .fault)
            throw error
        }

        return data
    }

    private static func resolve(_ data: Data) throws -> URL {
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: data,
                          options: .withSecurityScope,
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)
        } catch let error as CocoaError where error.code == .fileReadUnknown {
            let desc = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? "unknown"
            os_log("Unable to resolve bookmark. Reason: %@", log: .bookmark, type: .fault, desc)
            throw error
        } catch {
            os_log("Unable to resolve bookmark with unhandled error", log: .bookmark, type: .fault)
            throw error
        }

        // The isStale value is undocumented.
        if isStale {
            os_log("Resolved URL returned stale data from bookmark data", log: .bookmark, type: .fault)
        }

        return url
    }

}

// MARK: - Public extensions

extension OSLog {

    static let bookmark = OSLog(subsystem: "--", category: "SecurityScopedBookmark")

}
