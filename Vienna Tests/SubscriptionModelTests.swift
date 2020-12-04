//
//  SubscriptionModelTests.swift
//  Vienna Tests
//
//  Copyright 2020
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

class SubscriptionModelTests: XCTestCase {
    var subscriptionModel: SubscriptionModel?

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        subscriptionModel = SubscriptionModel()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        subscriptionModel = nil
        try super.tearDownWithError()
    }

    func testVerificationOfCompleteFileURLs() {
        // Test that when passed a complete file URL, the verification doesn't change the original
        let unverifiedURL = URL(string: "file:///Users/test/test.xml")!
        let expectedURL = URL(string:"file:///Users/test/test.xml")!

        XCTAssertEqual(expectedURL, subscriptionModel!.verifiedFeedURL(from: unverifiedURL))
    }

    func testVerificationOfCompleteWebURLs() {
        // Test that then passed a complete web URL to an rss feed, the verification doesn't change the original
        let unverifiedURL = URL(string: "https://www.vienna-rss.com/feed.xml")!
        let expectedURL = URL(string:"https://www.vienna-rss.com/feed.xml")!

        XCTAssertEqual(expectedURL, subscriptionModel!.verifiedFeedURL(from: unverifiedURL))
    }

    func testVerificationOfIncompleteWebURLs() {
        // Test that when passed a URL without an rss feed in the path component and without a scheme
        // that the returned URL is correct
        let unverifiedURL = URL(string: "www.vienna-rss.com")!
        let expectedURL = URL(string:"https://www.vienna-rss.com/feed.xml")!
        let verifiedURL = subscriptionModel!.verifiedFeedURL(from: unverifiedURL)!

        XCTAssertTrue(expectedURL.isEquivalent(verifiedURL))
    }

    func testVerificationOfHostRelativeWebURLs() {
        var unverifiedURL: URL, expectedURL: URL, verifiedURL: URL

        // Test that when passed a URL without an rss feed in the path component and without a scheme
        // that the returned URL is correct
        unverifiedURL = URL(string: "https://news.ycombinator.com/news")!
        expectedURL = URL(string:"https://news.ycombinator.com/rss")!
        verifiedURL = subscriptionModel!.verifiedFeedURL(from: unverifiedURL)!

        XCTAssertTrue(expectedURL.isEquivalent(verifiedURL))

        // Reported by @cdevroe from https://twitter.com/cdevroe/status/517764086478958593
        unverifiedURL = URL(string: "https://adactio.com/journal/")!
        expectedURL = URL(string: "https://adactio.com/journal/rss")!
        verifiedURL = subscriptionModel!.verifiedFeedURL(from: unverifiedURL)!

        XCTAssertTrue(expectedURL.isEquivalent(verifiedURL))

        // Reported by @cdevroe from from https://twitter.com/cdevroe/status/517764395183915009
        unverifiedURL = URL(string: "shawnblanc.net")!
        expectedURL = URL(string: "http://shawnblanc.net/feed/")!
        verifiedURL = subscriptionModel!.verifiedFeedURL(from: unverifiedURL)!

        XCTAssertTrue(expectedURL.isEquivalent(verifiedURL))
    }

}
