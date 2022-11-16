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

        let testCriteriaTree = genericConversionChecks(criteriaTreeString)

        XCTAssertTrue(testCriteriaTree.criteriaEnumerator.allObjects.first is Criteria, "Pass")

        let sqlString = testCriteriaTree.toSQL(for: database)

        XCTAssertEqual("\(flaggedField.sqlField!)=1", sqlString, "Sql correct")
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
                                <?xml version="1.0" encoding="UTF-8" standalone="yes"?><criteriagroup condition="all">
                                <criteria field="\(flaggedField.name!)"><operator>1</operator><value>Yes</value></criteria>
                                <criteria field="\(dateField.name!)"><operator>1</operator><value>today</value></criteria></criteriagroup>
                                """

        let testCriteriaTree = genericConversionChecks(criteriaTreeString)

        let allCriteria = testCriteriaTree.criteriaEnumerator.allObjects
        XCTAssertGreaterThan(allCriteria.count, 1, "Pass")

        let sqlString = testCriteriaTree.toSQL(for: database)

        XCTAssert(sqlString.contains("\(flaggedField.sqlField!)=1"), "Sql contains flagged criterion")
    }

    func testCanonicalizeNotFalseAndNotTrue() {
        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = """
                                <?xml version="1.0" encoding="UTF-8" standalone="yes"?><criteriagroup condition="all">
                                <criteria field="\(flaggedField.name!)"><operator>1</operator><value>Yes</value></criteria>
                                <criteria field="\(flaggedField.name!)"><operator>1</operator><value>No</value></criteria>
                                <criteria field="\(flaggedField.name!)"><operator>2</operator><value>Yes</value></criteria>
                                <criteria field="\(flaggedField.name!)"><operator>2</operator><value>No</value></criteria>
                                </criteriagroup>
                                """

        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }

        let sqlString = testCriteriaTree.toSQL(for: database)

        XCTAssertEqual(sqlString, "\(flaggedField.sqlField!)=1 AND \(flaggedField.sqlField!)=0 AND \(flaggedField.sqlField!)<>1 AND \(flaggedField.sqlField!)<>0", "Sql correct")

        let sqlStringAfterPredicateConversion = CriteriaTree(predicate: testCriteriaTree.predicate)?.toSQL(for: database)

        XCTAssertEqual(sqlStringAfterPredicateConversion, "\(flaggedField.sqlField!)=1 AND \(flaggedField.sqlField!)=0 AND \(flaggedField.sqlField!)=0 AND \(flaggedField.sqlField!)=1", "Canonicalization successful")
    }

    func testCriteriaTreeString() {
        // This tests returning a criteria tree as an XML string
        let criteriaTreeString = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><criteriagroup condition=\"all\"><criteria field=\"Flagged\"><operator>1</operator><value>Yes</value></criteria></criteriagroup>"

        genericConversionChecks(criteriaTreeString)
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

        let testCriteriaTree = genericConversionChecks(criteriaTreeString)

        let treeStringUnformatted: String = criteriaTreeString.replacingOccurrences(of: "  ", with: "").replacingOccurrences(of: "\n", with: "")
        XCTAssertEqual(treeStringUnformatted, testCriteriaTree.string, "XML reproducible")
    }

    func testNestedCriteriaSQLConversion() {
        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged"), let subjectField = database.field(byName: "Subject") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = """
                                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                                <criteriagroup condition="all">
                                    <criteria field="\(subjectField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Contains.rawValue)</operator><value>asdf</value></criteria>
                                    <criteriagroup condition="any">
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Is.rawValue)</operator><value>Yes</value></criteria>
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Is.rawValue)</operator><value>No</value></criteria>
                                    </criteriagroup>
                                </criteriagroup>
                                """

        let testCriteriaTree = genericConversionChecks(criteriaTreeString)

        XCTAssertEqual(testCriteriaTree.toSQL(for: database), "\(subjectField.sqlField!) LIKE '%asdf%' AND ( \(flaggedField.sqlField!)=1 OR \(flaggedField.sqlField!)=0 )")
    }

    func testNestedNotCriteriaSQLConversion() {
        let database = getDatabase()
        guard let flaggedField = database.field(byName: "Flagged"), let subjectField = database.field(byName: "Subject") else {
            fatalError("cannot happen")
        }

        // This tests initialising a CriteriaTree with a string that has
        // multiple criteria.
        // Only called by the Database class when loading smart folders
        let criteriaTreeString = """
                                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                                <criteriagroup condition="all">
                                    <criteria field="\(subjectField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Contains.rawValue)</operator><value>asdf</value></criteria>
                                    <criteriagroup condition="none">
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Is.rawValue)</operator><value>Yes</value></criteria>
                                        <criteria field="\(flaggedField.name!)"><operator>\(CriteriaOperator.MA_CritOper_Is.rawValue)</operator><value>No</value></criteria>
                                    </criteriagroup>
                                </criteriagroup>
                                """

        let testCriteriaTree = genericConversionChecks(criteriaTreeString)

        XCTAssertEqual(testCriteriaTree.toSQL(for: database), "\(subjectField.sqlField!) LIKE '%asdf%' AND ( NOT \(flaggedField.sqlField!)=1 AND NOT \(flaggedField.sqlField!)=0 )")
    }

    func testAllCriteriaConditions() {
        let criteriaTreeString = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <criteriagroup condition="all">
            <criteria field="Read"><operator>1</operator><value>Yes</value></criteria>
            <criteria field="Read"><operator>1</operator><value>No</value></criteria>
            <criteria field="Flagged"><operator>1</operator><value>Yes</value></criteria>
            <criteria field="Flagged"><operator>1</operator><value>No</value></criteria>
            <criteria field="HasEnclosure"><operator>1</operator><value>Yes</value></criteria>
            <criteria field="HasEnclosure"><operator>1</operator><value>No</value></criteria>
            <criteria field="Deleted"><operator>1</operator><value>Yes</value></criteria>
            <criteria field="Deleted"><operator>1</operator><value>No</value></criteria>
            <criteria field="Subject"><operator>1</operator><value>TestBetreff</value></criteria>
            <criteria field="Subject"><operator>2</operator><value>NichtTestBetreff</value></criteria>
            <criteria field="Subject"><operator>7</operator><value>BeinhaltetTestBetreff</value></criteria>
            <criteria field="Subject"><operator>8</operator><value>BeinhaltetNichtTestBetreff</value></criteria>
            <criteria field="Folder"><operator>1</operator><value>MacRumors: Mac News and Rumors - All Stories</value></criteria>
            <criteria field="Folder"><operator>2</operator><value>Mac &amp; i</value></criteria>
            <criteria field="Date"><operator>1</operator><value>yesterday</value></criteria>
            <criteria field="Date"><operator>10</operator><value>last week</value></criteria>
            <criteria field="Date"><operator>9</operator><value>today</value></criteria>
            <criteria field="Date"><operator>12</operator><value>yesterday</value></criteria>
            <criteria field="Date"><operator>11</operator><value>yesterday</value></criteria>
            <criteria field="Author"><operator>1</operator><value>TestAutor</value></criteria>
            <criteria field="Author"><operator>2</operator><value>NichtTestAutor</value></criteria>
            <criteria field="Author"><operator>7</operator><value>BeinhaltetTestAutor</value></criteria>
            <criteria field="Author"><operator>8</operator><value>BeinhaltetNichtTestAutort</value></criteria>
            <criteria field="Text"><operator>1</operator><value>TestText</value></criteria>
            <criteria field="Text"><operator>2</operator><value>NichtTestText</value></criteria>
            <criteria field="Text"><operator>7</operator><value>BeinhaltetTestText</value></criteria>
            <criteria field="Text"><operator>8</operator><value>BeinhaltetNichtTestText</value></criteria>
        </criteriagroup>
        """

        genericConversionChecks(criteriaTreeString)
    }

    func testNegation() {
        let testCriteriaString = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <criteriagroup condition="none">
            <criteria field="Folder"><operator>2</operator><value>Apple Newsroom</value></criteria>
            <criteria field="Text"><operator>7</operator><value>Apple</value></criteria>
        </criteriagroup>
        """

        // Same test as above (none predicate at the beginning and "not contains Apple" are the relevant things to test here)

        genericConversionChecks(testCriteriaString)
    }

    private func genericConversionChecks(_ criteriaTreeString: String) -> CriteriaTree {
        guard let testCriteriaTree = CriteriaTree(string: criteriaTreeString) else {
            XCTAssert(false)
            fatalError("cannot happen")
        }

        let treeStringUnformatted: String = criteriaTreeString.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "  ", with: "")
        XCTAssertEqual(treeStringUnformatted, testCriteriaTree.string, "XML reproducible")

        XCTAssertNotNil(testCriteriaTree.toSQL(for: getDatabase()))

        XCTAssertEqual(CriteriaTree(predicate: testCriteriaTree.predicate)!.string, treeStringUnformatted, "Still same xml after converting to predicate and back")

        return testCriteriaTree
    }

    private func getDatabase() -> Database {
        guard let database = Database.shared else {
            XCTAssertTrue(false)
            fatalError("cannot happen")
        }
        return database
    }
}
