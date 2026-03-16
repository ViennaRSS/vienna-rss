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

        data.withUnsafeBytes { bufferPointer in
            var handler = htmlParserHandler()
            let parser = Unmanaged.passUnretained(self).toOpaque()
            let baseAddress = bufferPointer.bindMemory(to: CChar.self).baseAddress
            let numberOfBytes = Int32(bufferPointer.count)
            let filename: UnsafePointer<CChar>? = nil
            let encoding = xmlDetectCharEncoding(baseAddress, numberOfBytes)
            parserContext = htmlCreatePushParserCtxt(
                &handler,
                parser,
                baseAddress,
                numberOfBytes,
                filename,
                encoding
            )
        }

        // HTML_PARSE_NONET is unimplemented and will result in a non-zero
        // return code of htmlCtxtUseOptions(_:_:).
        let opts = Int32(HTML_PARSE_RECOVER.rawValue | HTML_PARSE_NOBLANKS.rawValue)
        if htmlCtxtUseOptions(parserContext, opts) != 0 {
            os_log(
                "Parser returned non-zero return code for options",
                log: .htmlParser,
                type: .fault,
                baseURL.absoluteString
            )
        }

        if htmlParseDocument(parserContext) != 0,
            let error = xmlCtxtGetLastError(parserContext)?.pointee,
            let message = error.message
        {
            os_log(
                "Parser returned non-zero return code for URL %@. Last error message: %@ (%i)",
                log: .htmlParser,
                type: error.level == XML_ERR_FATAL ? .error : .debug,
                baseURL.absoluteString,
                String(cString: message).trimmingCharacters(in: .newlines),
                error.code
            )
        }

        htmlFreeParserCtxt(parserContext)
        parserContext = nil
    }

    func abortParsing() {
        if let parserContext {
            xmlStopParser(parserContext)
        }
    }

    private func htmlParserHandler() -> htmlSAXHandler {
        var handler = libxml2.htmlSAXHandler()
        handler.startElement = { parserPointer, elementNamePointer, attributesArrayPointer in
            guard let parserPointer, let elementNamePointer else {
                return
            }

            let parser = Unmanaged<HTMLParser>.fromOpaque(parserPointer).takeUnretainedValue()

            HTMLParser.didStartElement(
                parser,
                elementNamePointer: elementNamePointer,
                attributesArrayPointer: attributesArrayPointer
            )
        }
        return handler
    }

    private static func didStartElement(
        _ parser: HTMLParser,
        elementNamePointer: UnsafePointer<xmlChar>,
        attributesArrayPointer: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?
    ) {
        guard let delegate = parser.delegate else {
            return
        }

        let elementName = String(cString: elementNamePointer)

        // The C array consists of one or more key–value pairs of C strings.
        var attributes = [String: String]()
        var currentAttributeIndex = 0
        var currentAttributeKey: String?
        while let attribute = attributesArrayPointer?[currentAttributeIndex] {
            if let attributeKey = currentAttributeKey {
                attributes[attributeKey] = String(cString: attribute)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentAttributeKey = nil
            } else {
                currentAttributeKey = String(cString: attribute)
            }
            currentAttributeIndex += 1
        }

        delegate.parser(parser, didStartElement: elementName, attributes: attributes)
    }

}

extension OSLog {

    fileprivate static let htmlParser = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "--",
        category: "HTMLParser"
    )

}
