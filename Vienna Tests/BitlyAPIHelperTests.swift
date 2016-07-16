//
//  BitlyAPIHelperTests.swift
//  Vienna
//
//  Created by Joshua Pore on 16/07/2016.
//  Copyright © 2016 uk.co.opencommunity. All rights reserved.
//

import XCTest

class BitlyAPIHelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testShortenURL() {
        let bitlyHelper = BitlyAPIHelper.init(login: "viennarss", andAPIKey: "R_852929122e82d2af45fe9e238f1012d3")
        let shortURL = bitlyHelper.shortenURL("http://www.vienna-rss.org")
        XCTAssertTrue(shortURL.containsString("bit.ly"))
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }

}
