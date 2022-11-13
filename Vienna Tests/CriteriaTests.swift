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

        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><criteriagroup condition=\"all\"><criteria field=\"\(flaggedField.name!)\"><operator>1</operator><value>Yes</value></criteria></criteriagroup>"

        let treeStringUnformatted: String = criteriaTreeString.replacingOccurrences(of: "  ", with: "").replacingOccurrences(of: "\n", with: "")

        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }
        XCTAssertTrue(testCriteriaTree.criteriaEnumerator.allObjects.first is Criteria, "Pass")

        XCTAssertEqual(treeStringUnformatted, testCriteriaTree.string)

        let sqlString = testCriteriaTree.toSQL(for: database)

        XCTAssertEqual("\(flaggedField.sqlField!)=1", sqlString, "Sql correct")

        let predicate = testCriteriaTree.predicate

        let testCriteriaTreeFromPredicate = CriteriaTree(predicate: predicate)

        XCTAssertEqual(treeStringUnformatted, testCriteriaTreeFromPredicate.string)
    }

    func testCriteriaTreeInitWithString2() {

        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged"), let dateField = database.field(byName: "Date") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = """
                                <?xml version="1.0" encoding="utf-8"?><criteriagroup condition="all">
                                <criteria field="\(flaggedField.name!)"><operator>1</operator><value>Yes</value></criteria>
                                <criteria field="\(dateField.name!)"><operator>1</operator><value>today</value></criteria></criteriagroup>
                                """

        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }
        let allCriteria = testCriteriaTree.criteriaEnumerator.allObjects
        XCTAssertGreaterThan(allCriteria.count, 1, "Pass")

        let sqlString = testCriteriaTree.toSQL(for: database)!

        XCTAssert(sqlString.contains("\(flaggedField.sqlField!)=1"), "Sql contains flagged criterion")
    }

    func testCriteriaTreeString() {
        // This tests returning a criteria tree as an XML string
        let criteriaTreeString = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria></criteriagroup>"

        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }
        XCTAssertEqual(testCriteriaTree.string, criteriaTreeString)
    }

    func testNestedCriteriaXMLConversion() {
        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged"), let dateField = database.field(byName: "Date") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = """
                                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                                <criteriagroup condition="all">
                                    <criteria field="\(flaggedField.name!)"><operator>1</operator><value>Yes</value></criteria>
                                    <criteria field="\(dateField.name!)"><operator>1</operator><value>today</value></criteria>
                                    <criteriagroup condition="all">
                                        <criteria field="\(flaggedField.name!)"><operator>1</operator><value>Yes</value></criteria>
                                        <criteria field="\(dateField.name!)"><operator>1</operator><value>today</value></criteria>
                                    </criteriagroup>
                                </criteriagroup>
                                """

        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }

        let treeStringUnformatted: String = criteriaTreeString.replacingOccurrences(of: "  ", with: "").replacingOccurrences(of: "\n", with: "")
        XCTAssertEqual(treeStringUnformatted, testCriteriaTree.string, "XML reproducible")
    }

    func testNestedCriteriaSQLConversion() {
        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged"), let commentsField = database.field(byName: "Comments") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = """
                                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                                <criteriagroup condition="all">
                                    <criteria field="\(commentsField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Contains.rawValue)</operator><value>asdf</value></criteria>
                                    <criteriagroup condition="any">
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Is.rawValue)</operator><value>Yes</value></criteria>
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_IsNot.rawValue)</operator><value>No</value></criteria>
                                    </criteriagroup>
                                </criteriagroup>
                                """

        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }

        XCTAssertEqual(testCriteriaTree.toSQL(for: database), "\(commentsField.sqlField!) LIKE '%asdf%' AND ( \(flaggedField.sqlField!)=1 OR \(flaggedField.sqlField!)<>0 )")
    }

    func testNestedNotCriteriaSQLConversion() {
        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged"), let commentsField = database.field(byName: "Comments") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = """
                                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                                <criteriagroup condition="all">
                                    <criteria field="\(commentsField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Contains.rawValue)</operator><value>asdf</value></criteria>
                                    <criteriagroup condition="none">
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Is.rawValue)</operator><value>Yes</value></criteria>
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_IsNot.rawValue)</operator><value>No</value></criteria>
                                    </criteriagroup>
                                </criteriagroup>
                                """

        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }

        XCTAssertEqual(testCriteriaTree.toSQL(for: database), "\(commentsField.sqlField!) LIKE '%asdf%' AND ( NOT \(flaggedField.sqlField!)=1 AND NOT \(flaggedField.sqlField!)<>0 )")
    }

    private func getDatabase() -> Database {
        guard let database = Database.shared else {
            XCTAssertTrue(false)
            fatalError("cannot happen")
        }
        return database
    }
}
