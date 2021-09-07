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

    var tempURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let downloadsDirectory = FileManager.default.downloadsDirectory
        tempURL = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: downloadsDirectory, create: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempURL)

        try super.tearDownWithError()
    }

    /// Test helper method to return an array of folders for export
    func foldersArray() -> [Any] {
        guard let database = Database.shared else {
            XCTAssertTrue(false)
            fatalError("cannot happen")
        }
        return database.arrayOfAllFolders()
    }

    // MARK: Export Tests

    func testExportWithoutGroups() {
        // Test exporting feeds to opml file without groups
        let folders = self.foldersArray()
        let tmpUrl = tempURL.appendingPathComponent("vienna-test-nogroups.opml", isDirectory: false)
        let countExported = Export.export(toFile: tmpUrl.path, from: folders, in: nil, withGroups: false)
        XCTAssertGreaterThan(countExported, 0, "Pass")
    }

    func testExportWithGroups() {
        // Test exporting feeds to opml file without groups
        let folders = self.foldersArray()
        let tmpUrl = tempURL.appendingPathComponent("vienna-test-groups.opml", isDirectory: false)
        let countExported = Export.export(toFile: tmpUrl.path, from: folders, in: nil, withGroups: true)
        XCTAssertGreaterThan(countExported, 0, "Pass")
    }

}
