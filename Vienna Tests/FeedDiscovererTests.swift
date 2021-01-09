//
//  FeedDiscovererTests.swift
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

class FeedDiscovererTests: XCTestCase {

    static let dummyURL: URL! = URL(string: "https://www.vienna-rss.com")

    var testData: Data!

    override func setUp() {
        super.setUp()

        let bundle = Bundle(for: FeedDiscovererTests.self)
        guard let htmlFile = bundle.url(forResource: "FeedDiscovery", withExtension: "html") else {
            XCTFail("FeedDiscovery.html file missing")
            return
        }

        guard let htmlData = try? String(contentsOf: htmlFile).data(using: .utf8) else {
            XCTFail("FeedDiscovery.html data ostensibly invalid")
            return
        }

        testData = htmlData
    }

    override func tearDown() {
        super.tearDown()

        testData = nil
    }

    /// Check the FeedDiscovery.html file for valid feed references.
    func testDiscoveringFeeds() {
        let discoverer = FeedDiscoverer(data: testData, baseURL: FeedDiscovererTests.dummyURL)

        XCTAssert(discoverer.documentHasFeeds())
        XCTAssert(discoverer.feedURLs().count == 10)
    }

}
