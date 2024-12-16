//
//  FeedDiscoverer.swift
//  Vienna
//
//  Copyright 2020-2021, 2024 Eitot
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

@objc(VNAFeedDiscoverer)
final class FeedDiscoverer: NSObject {

    /// A data object containing the HTML document.
    @objc let data: Data

    /// The base URL of the HTML document.
    @objc let baseURL: URL

    // MARK: Initialization

    /// Initializes a feed discoverer with the HTML contents encapsulated in a
    /// given data object.
    ///
    /// - Parameters:
    ///   - data: A data object containing the HTML document.
    ///   - baseURL: The base URL of the HTML document.
    @objc
    init(data: Data, baseURL: URL) {
        self.data = data
        self.baseURL = baseURL
    }

    // MARK: Parsing

    private lazy var results: [FeedURL] = []

    private var abortOnFirstResult = false

    /// Searches the HTML document for feed URLs.
    @objc
    func documentHasFeeds() -> Bool {
        abortOnFirstResult = true
        parse()

        return !results.isEmpty
    }

    /// Extracts feed URLs from the HTML document.
    /// - Returns: An array of feed URLs.
    @objc
    func feedURLs() -> [FeedURL] {
        abortOnFirstResult = false
        parse()

        return results
    }

    private func parse() {
        let parser = HTMLParser(data: data, baseURL: baseURL, delegate: self)
        parser.parse()
    }

    // MARK: Validating

    // Verifies whether an HTML element refers to a feed.
    //
    // The validation is based upon the HTML5 living standard, last accessed on
    // 4th January 2021 at: https://html.spec.whatwg.org/multipage/links.html\.
    //
    // See also:
    // https://validator.w3.org/feed/docs/warning/UnexpectedContentType.html\.
    private func validateElement(elementName: String, attributes: [String: String]) -> Bool {
        // The link element and alternate relation represent external content.
        guard elementName == "link" && attributes["rel"]?.lowercased() == "alternate" else {
            return false
        }

        switch attributes["type"]?.lowercased() {
        // These types are recommended, requiring no further validation.
        case "application/rss+xml",
             "application/atom+xml",
             "application/feed+json",
             "application/json":
            return true
        // These types are not sanctioned, but nevertheless used. They require
        // further validation to rule out false-positives.
        case "application/xml",
             "application/rdf+xml",
             "text/xml":
            break
        default:
            return false
        }

        // At this point, the link could refer to any type of XML document. The
        // document name can be the final clue.
        switch attributes["href"]?.lowercased() {
        case .some(let urlString) where urlString.contains("feed") || urlString.contains("rss"):
            return true
        default:
            return false
        }
    }

    // Formats the href attribute into an absolute URL, if possible.
    private func formatURL(attributes: [String: String], baseURL: URL) -> URL? {
        guard
            let urlString = attributes["href"],
            let components = URLComponents(string: urlString),
            let absoluteFeedURL = components.url(relativeTo: baseURL)
        else {
            return nil
        }

        return absoluteFeedURL.absoluteURL
    }

}

// MARK: - Nested types

@objc(VNAFeedURL)
class FeedURL: NSObject {
    @objc let absoluteURL: URL
    @objc let title: String?

    @objc(initWithURL:title:)
    init(url: URL, title: String?) {
        absoluteURL = url
        self.title = title
    }
}

// MARK: - HTMLParserDelegate

extension FeedDiscoverer: HTMLParserDelegate {

    func parser(
        _ parser: HTMLParser,
        didStartElement elementName: String,
        attributes: [String: String]
    ) {
        guard
            validateElement(elementName: elementName, attributes: attributes),
            let absoluteURL = formatURL(attributes: attributes, baseURL: parser.baseURL)
        else {
            return
        }

        let feedURL = FeedURL(url: absoluteURL, title: attributes["title"])
        results.append(feedURL)

        if abortOnFirstResult {
            parser.abortParsing()
        }
    }

}
