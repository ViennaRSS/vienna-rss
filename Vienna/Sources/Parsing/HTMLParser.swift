//
//  HTMLParser.swift
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
import libxml2
import os.log

class HTMLParser {

    /// A data object containing the HTML document.
    let data: Data

    /// The base URL of the HTML document.
    let baseURL: URL

    /// The delegate object that receives messages about the parsing process.
    private(set) weak var delegate: (any HTMLParserDelegate)?

    // MARK: Initialization

    // This static property ensures that xmlInitParser() is called only once,
    // even if this class is instantiated multiple times.
    private static let htmlParserInitializer: Void = xmlInitParser()

    /// Initializes a parser with the HTML contents encapsulated in a given data
    /// object.
    ///
    /// - Parameters:
    ///   - data: A data object containing the HTML document.
    ///   - baseURL: The base URL of the HTML document.
    ///   - delegate: The object that receives messages about the parsing process.
    init(data: Data, baseURL: URL, delegate: any HTMLParserDelegate) {
        // Call the static initializer of xmlInitParser().
        Self.htmlParserInitializer

        self.data = data
        self.baseURL = baseURL
        self.delegate = delegate
    }

    // MARK: Parsing

    private var parserContext: htmlParserCtxtPtr?

    func parse() {
        guard parserContext == nil else {
            return
        }

        data.withUnsafeBytes { buffer in
            // According to the UnsafeRawBufferPointer documentation, each byte
            // is addressed as a UInt8 value.
            guard let baseAddress = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                os_log("Buffer base address is nil", log: .htmlParser, type: .fault)
                return
            }

            let numberOfBytes = Int32(buffer.count)

            // Even if the base address is not nil, the byte count can be 0.
            guard numberOfBytes > 0 else {
                os_log("Buffer data count is 0", log: .htmlParser, type: .fault)
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

    func abortParsing() {
        if let parserContext {
            xmlStopParser(parserContext)
        }
    }

    private func htmlParserHandler() -> htmlSAXHandler {
        var handler = libxml2.htmlSAXHandler()
        handler.startElement = htmlParserElementStart
        return handler
    }

}

private func htmlParserElementStart(
    _ parser: UnsafeMutableRawPointer?,
    elementName: UnsafePointer<xmlChar>?,
    attributesArray: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?
) {
    guard let pointer = parser, let cString = elementName else {
        os_log("Parser returned nil pointers", log: .htmlParser, type: .fault)
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

    let parser = Unmanaged<HTMLParser>.fromOpaque(pointer).takeUnretainedValue()
    let elementName = String(cString: cString)
    parser.delegate?.parser(parser, didStartElement: elementName, attributes: attributes)
}

private extension OSLog {

    static let htmlParser = OSLog(subsystem: "--", category: "HTMLParser")

}
