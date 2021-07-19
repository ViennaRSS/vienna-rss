//
//  ExportTests.swift
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

class ExportTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }

    /// Test helper method to return an array of folders for export
    func foldersArray() -> [Any] {
        let db = Database.shared!
        return db.arrayOfAllFolders()
    }

    // MARK: Export Tests

    func testExportWithoutGroups() {
        // Test exporting feeds to opml file without groups
        let folders = self.foldersArray()
        let tmpUrl = URL(string: "/tmp/vienna-test-nogroups.opml")!

        let countExported = Export.export(toFile: tmpUrl.absoluteString, from: folders, in: nil, withGroups: false)
        XCTAssertGreaterThan(countExported, 0, "Pass")
    }

    func testExportWithGroups() {
        // Test exporting feeds to opml file without groups
        let folders = self.foldersArray()
        let tmpUrl = URL(string: "/tmp/vienna-test-groups.opml")!

        let countExported = Export.export(toFile: tmpUrl.absoluteString, from: folders, in: nil, withGroups: true)
        XCTAssertGreaterThan(countExported, 0, "Pass")
    }

}
