//
//  FeedDiscoverer.swift
//  Vienna
//
//  Copyright 2020-2021 Eitot
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
import libxml2
import os.log

@objc(VNAFeedDiscoverer)
final class FeedDiscoverer: NSObject {

    /// A data object containing the HTML document.
    @objc let data: Data

    /// The base URL of the HTML document.
    @objc let baseURL: URL

    // MARK: Initialization

    // This static property ensures that xmlInitParser() is called only once,
    // even if this class is instantiated multiple times.
    private static let htmlParser: Void = xmlInitParser()

    /// Initializes a parser with the HTML contents encapsulated in a given data
    /// object.
    ///
    /// - Parameters:
    ///   - data: A data object containing the HTML document.
    ///   - baseURL: The base URL of the HTML document.
    @objc
    init(data: Data, baseURL: URL) {
        // Call the static initializer of xmlInitParser().
        FeedDiscoverer.htmlParser

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

    private var parserContext: htmlParserCtxtPtr?

    private func parse() {
        guard parserContext == nil else {
            return
        }

        data.withUnsafeBytes { buffer in
            // According to the UnsafeRawBufferPointer documentation, each byte
            // is addressed as a UInt8 value.
            guard let baseAddress = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                os_log("Buffer base address is nil", log: .discoverer, type: .fault)
                return
            }

            let numberOfBytes = Int32(buffer.count)

            // Even if the base address is not nil, the byte count can be 0.
            guard numberOfBytes > 0 else {
                os_log("Buffer data count is 0", log: .discoverer, type: .fault)
                return
            }

            // Set up the HTML parser.
            var handler = htmlParserHandler()
            let parser = Unmanaged.passUnretained(self).toOpaque()
            let address = UnsafeRawPointer(baseAddress).bindMemory(to: Int8.self, capacity: 1)
            let encoding = xmlDetectCharEncoding(baseAddress, numberOfBytes)
            parserContext = htmlCreatePushParserCtxt(&handler, parser, address, numberOfBytes, nil, encoding)

            let opts = Int32(HTML_PARSE_RECOVER.rawValue | HTML_PARSE_NOBLANKS.rawValue | HTML_PARSE_NONET.rawValue)
            htmlCtxtUseOptions(parserContext, opts)

            // Parse the document.
            htmlParseDocument(parserContext)

            // Clean up the parser.
            htmlFreeParserCtxt(parserContext)
            self.parserContext = nil
        }
    }

    fileprivate func parser(_ parser: FeedDiscoverer, didStartElement elementName: String, attributes: [String: String]) {
        guard validateElement(elementName: elementName, attributes: attributes) else {
            return
        }

        guard let absoluteURL = formatURL(attributes: attributes, baseURL: parser.baseURL) else {
            return
        }

        let feedURL = FeedURL(url: absoluteURL, title: attributes["title"])
        parser.results.append(feedURL)

        if parser.abortOnFirstResult {
            xmlStopParser(parserContext)
            return
        }
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
             "application/atom+xml":
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
        guard let urlString = attributes["href"] else {
            return nil
        }

        guard let components = URLComponents(string: urlString) else {
            return nil
        }

        guard let absoluteFeedURL = components.url(relativeTo: baseURL) else {
            return nil
        }

        return absoluteFeedURL.absoluteURL
    }

}

// MARK: - Nested types

@objc(VNAFeedURL)
final class FeedURL: NSObject {
    @objc let absoluteURL: URL
    @objc let title: String?

    @objc(initWithURL:title:)
    init(url: URL, title: String?) {
        absoluteURL = url
        self.title = title
    }
}

// MARK: - libxml2 handlers

private func htmlParserHandler() -> htmlSAXHandler {
    var handler = libxml2.htmlSAXHandler()
    handler.startElement = htmlParserElementStart
    return handler
}

private func htmlParserElementStart(_ parser: UnsafeMutableRawPointer?, elementName: UnsafePointer<xmlChar>?, attributesArray: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?) {
    guard let pointer = parser, let cString = elementName else {
        os_log("Parser returned nil pointers", log: .discoverer, type: .fault)
        return
    }

    // Each element of the C array consists of two NULL terminated C strings.
    var attributes: [String: String] = [:]
    var currentAttributeIndex = 0
    var currentAttributeKey: String?

    while true {
        guard let attribute = attributesArray?[currentAttributeIndex] else {
            break
        }

        // If the key is present, parse the attribute value.
        if let arrayKey = currentAttributeKey {
            attributes[arrayKey] = String(cString: attribute)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            currentAttributeKey = nil
        // No key is present, therefore parse a key first.
        } else {
            currentAttributeKey = String(cString: attribute)
        }

        currentAttributeIndex += 1
    }

    let parser = Unmanaged<FeedDiscoverer>.fromOpaque(pointer).takeUnretainedValue()
    let elementName = String(cString: cString)
    parser.parser(parser, didStartElement: elementName, attributes: attributes)
}

// MARK: - Public extensions

extension OSLog {

    static let discoverer = OSLog(subsystem: "--", category: "FeedDiscoverer")

}
