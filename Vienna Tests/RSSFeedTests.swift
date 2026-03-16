//
//  RSSFeedTests.swift
//  Vienna Tests
//
//  Copyright 2024 Eitot
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

import XCTest

class RSSFeedTests: XCTestCase {

    // MARK: Test methods

    func testParsingItemElementUnderRSSElement() throws {
        let fileData = try data(
            forResource: "RSSFeedWithItemElementUnderRSSElement",
            withExtension: "rss"
        )
        let feedData = try VNAXMLFeedParser().feed(withXMLData: fileData)
        let rssFeed = try XCTUnwrap(feedData as? RSSFeed)
        let feedItems = rssFeed.items

        XCTAssert(feedItems.count == 1)
        XCTAssert(feedItems.first?.guid == "itemGUID")
    }

    func testParsingItemElementUnderRSSAndChannelElement() throws {
        let fileData = try data(
            forResource: "RSSFeedWithItemElementUnderRSSAndChannelElement",
            withExtension: "rss"
        )
        let feedData = try VNAXMLFeedParser().feed(withXMLData: fileData)
        let rssFeed = try XCTUnwrap(feedData as? RSSFeed)
        let feedItems = rssFeed.items

        XCTAssert(feedItems.count == 1)
        XCTAssert(feedItems.first?.guid == "channelItemGUID")
    }

    /// Validate the content:encoded elements.
    func testParsingContentElement() throws {
        let fileData = try data(forResource: "RSSFeedWithContentElements", withExtension: "rss")
        let feedData = try VNAXMLFeedParser().feed(withXMLData: fileData)
        let rssFeed = try XCTUnwrap(feedData as? RSSFeed)
        let feedItems = rssFeed.items

        XCTAssert(feedItems.count == 5)

        for item in feedItems {
            switch item.guid {
            case "nonEmptyContent1", "nonEmptyContent2":
                XCTAssert(item.content == "Item content")
            case "emptyContent1", "emptyContent2", "emptyContent3":
                XCTAssert(item.content == "Item description")
            default:
                XCTFail("Unexpected item")
            }
        }
    }

    // MARK: Test utilities

    func data(forResource name: String, withExtension ext: String) throws -> Data {
        let bundle = Bundle(for: RSSFeedTests.self)
        let fileURL = try XCTUnwrap(bundle.url(forResource: name, withExtension: ext))
        let fileContent = try String(contentsOf: fileURL)
        return try XCTUnwrap(fileContent.data(using: .utf8))
    }

}
