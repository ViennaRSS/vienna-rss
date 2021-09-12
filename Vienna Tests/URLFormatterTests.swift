//
//  URLFormatterTests.swift
//  Vienna Tests
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

@testable import Vienna
import XCTest

class URLFormatterTests: XCTestCase {

    var formatter: URLFormatter?

    func testStringFromHTTPURL() {
        formatter = URLFormatter()
        XCTAssertNotNil(formatter)

        let urlTuples = [
            (unformatted: "http://", formatted: "http://"),
            (unformatted: "http://host", formatted: "http://host"),
            (unformatted: "http://host/", formatted: "http://host"),
            (unformatted: "http://host/path?queries", formatted: "http://host/path?queries"),
            (unformatted: "http://host/path#fragment", formatted: "http://host/path#fragment"),
        ]

        for tuple in urlTuples {
            let url = URL(string: tuple.unformatted)
            XCTAssertNotNil(url)
            XCTAssertEqual(formatter!.string(from: url!), tuple.formatted)
        }
    }

    func testStringFromHTTPSURL() {
        formatter = URLFormatter()
        XCTAssertNotNil(formatter)

        let urlTuples = [
            (unformatted: "https://", formatted: "https://"),
            (unformatted: "https://host", formatted: "https://host"),
            (unformatted: "https://host/", formatted: "https://host"),
            (unformatted: "https://host/path?queries", formatted: "https://host/path?queries"),
            (unformatted: "https://host/path#fragment", formatted: "https://host/path#fragment"),
        ]

        for tuple in urlTuples {
            let url = URL(string: tuple.unformatted)
            XCTAssertNotNil(url)
            XCTAssertEqual(formatter!.string(from: url!), tuple.formatted)
        }
    }

    func testStringFromMailtoURL() {
        formatter = URLFormatter()
        XCTAssertNotNil(formatter)

        let urlTuples = [
            (unformatted: "mailto:recipient@host", formatted: "Send email to recipient@host"),
            (unformatted: "mailto:recipient@host?subject=Hello", formatted: "Send email to recipient@host with subject “Hello”"),
        ]

        for tuple in urlTuples {
            let url = URL(string: tuple.unformatted)
            XCTAssertNotNil(url)
            XCTAssertEqual(formatter!.string(from: url!), tuple.formatted)
        }
    }

}
