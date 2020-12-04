//
//  CriteriaTests.swift
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

class CriteriaTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }

    // MARK: Criteria Tests

    func testCriteriaTreeInitWithString() {
        // This tests initialising a CriteriaTree with a string.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = "<?xml version=\"1.0\" encoding=\"utf-8\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria></criteriagroup>"

        let testCriteriaTree = CriteriaTree(string: criteriaTreeString)!
        XCTAssertTrue(testCriteriaTree.criteriaEnumerator.allObjects.first is Criteria, "Pass")
    }

    func testCriteriaTreeInitWithString2() {
        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = "<?xml version=\"1.0\" encoding=\"utf-8\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria><criteria field=\"Date\"><operator>1</operator><value>today</value></criteria></criteriagroup>"

        let testCriteriaTree = CriteriaTree(string: criteriaTreeString)!
        let allCriteria = testCriteriaTree.criteriaEnumerator.allObjects;
        XCTAssertGreaterThan(allCriteria.count, 1, "Pass")
    }

    func testCriteriaTreeString() {
        // This tests returning a criteria tree as an XML string
        let criteriaTreeString = "<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria></criteriagroup>"

        let testCriteriaTree = CriteriaTree(string: criteriaTreeString)!
        XCTAssertEqual(testCriteriaTree.string.lowercased(), criteriaTreeString.lowercased())
    }

}
