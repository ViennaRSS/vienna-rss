//
//  URLFormatter.swift
//  Vienna
//
//  Copyright 2021 Eitot
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

@objc(VNAURLFormatter)
final class URLFormatter: Formatter {

    /// The supported URL schemes for this formatter.
    private enum Scheme: String {
        case http
        case https
        case mailto
        case javascript
    }

    // MARK: Properties

    /// These attributes determine the default style of the URL string. These
    /// are overridden by `primaryAttributes` and `secondaryAttributes`.
    @objc var defaultAttributes: [NSAttributedString.Key: Any] = [:]

    /// These attributes determine the general look of the URL string, except
    /// for the parts with secondary attributes.
    @objc var primaryAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.labelColor
    ]

    /// These attributes determine the look of less important parts of the URL
    /// string, such as the path and query components of a URL.
    @objc var secondaryAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.secondaryLabelColor
    ]

    // MARK: Methods

    /// Formats a given URL into a string.
    ///
    /// - Parameter url: The URL to be formatted.
    /// - Returns: A formatted URL string.
    @objc(stringFromURL:)
    func string(from url: URL) -> String {
        return string(for: url) ?? url.absoluteString
    }

    /// Formats a given URL into an attributed string.
    ///
    /// The attributed string will be formatted using `primaryAttributes` and
    /// `secondaryAttributes`. By default, it will format the scheme, username,
    /// password, host and port components of the URL using `primaryAttributes`;
    /// the rest of the URL is formatted using `secondaryAttributes`.
    ///
    /// - Parameter url: The URL to be formatted.
    /// - Returns: A formatted URL attributed string.
    @objc(attributedStringFromURL:)
    func attributedString(from url: URL) -> NSAttributedString {
        let attrString = attributedString(for: url, withDefaultAttributes: defaultAttributes)
        return attrString ?? NSAttributedString(string: url.absoluteString, attributes: defaultAttributes)
    }

    // MARK: Overrides

    override func string(for obj: Any?) -> String? {
        guard let url = obj as? URL else {
            return nil
        }

        if let supportedScheme = Scheme(rawValue: url.scheme?.lowercased() ?? "unsupported") {
            return string(for: supportedScheme, url: url)
        } else {
            return nil
        }
    }

    override func attributedString(for obj: Any, withDefaultAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString? {
        guard let url = obj as? URL else {
            return nil
        }

        if let supportedScheme = Scheme(rawValue: url.scheme?.lowercased() ?? "unsupported") {
            let attributes = attrs ?? defaultAttributes
            return attributedString(for: supportedScheme, url: url, withDefaultAttributes: attributes)
        } else {
            return nil
        }
    }

    // The documentation recommends overriding this method. It is unclear for
    // which purpose. For now, simply convert the string to an NSURL object.
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if let url = NSURL(string: string) {
            obj?.pointee = url
            return true
        } else {
            error?.pointee = NSString(string: "Failed to create NSURL")
            return false
        }
    }

    // MARK: Helper methods

    private func string(for scheme: Scheme, url: URL) -> String {
        switch scheme {
        case .http, .https:
            return urlStringWhileRemovingSlash(from: url)
        case .mailto:
            // The "mailto:" scheme tells the user that the default handling
            // will create an email for the recipient.
            let urlString = url.absoluteString
            guard let urlComponents = URLComponents(string: urlString) else {
                return urlString
            }

            let recipient = urlComponents.path
            guard let items = urlComponents.queryItems,
                  let subjectItem = items.first(where: { $0.name.caseInsensitiveCompare("subject") == .orderedSame }),
                  let subject = subjectItem.value else {
                return String(format: NSLocalizedString("Send email to %@", comment: "A formatted URL string with the mailto: URL scheme."), recipient)
            }
            return String(format: NSLocalizedString("Send email to %@ with subject “%@”", comment: "A formatted URL string with the mailto: URL scheme."), recipient, subject)
        case .javascript:
            // The actual components after the "javascript:" scheme component
            // are not accessible to URL or URLComponents.
            guard let script = (url as NSURL).resourceSpecifier else {
                return ""
            }
            return String(format: NSLocalizedString("Run script “%@”", comment: "A formatted URL string with the javascript: URL scheme."), script)
        }
    }

    private func attributedString(for scheme: Scheme, url: URL, withDefaultAttributes attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        switch scheme {
        case .http, .https:
            let urlString = urlStringWhileRemovingSlash(from: url)
            let attributes = attributes.merging(secondaryAttributes) { _, newValue in newValue }
            let attrURLString = NSMutableAttributedString(string: urlString, attributes: attributes)

            guard let urlComponents = NSURLComponents(string: urlString) else {
                return NSAttributedString(attributedString: attrURLString)
            }
            // Only this part of the URL: scheme://user:password@host:port
            let ranges = [
                urlComponents.rangeOfScheme,
                urlComponents.rangeOfUser,
                urlComponents.rangeOfPassword,
                urlComponents.rangeOfHost,
                urlComponents.rangeOfPort
            ].filter { $0.location != NSNotFound }
            guard let rangeBegin = ranges.first, let rangeEnd = ranges.last else {
                return NSAttributedString(attributedString: attrURLString)
            }
            let range = NSUnionRange(rangeBegin, rangeEnd)

            attrURLString.addAttributes(primaryAttributes, range: range)
            return NSAttributedString(attributedString: attrURLString)
        case .mailto, .javascript:
            // No special handling needed for attributed strings.
            let formattedString = string(for: scheme, url: url)
            return NSAttributedString(string: formattedString)
        }
    }

    /// This method removes the final slash if the URL has no path, query and
    /// fragment components, basically only the URL scheme and authority (e.g.
    /// `scheme://user:password@host:port/`).
    private func urlStringWhileRemovingSlash(from url: URL) -> String {
        var urlString = url.absoluteString

        guard urlString.hasSuffix("/") else {
            return urlString
        }

        guard let urlComponents = URLComponents(string: urlString),
              urlComponents.path == "/",
              urlComponents.query == nil,
              urlComponents.fragment == nil else {
            return urlString
        }

        urlString.removeLast()
        return urlString
    }

}
