//
//  UnarchiverTests.swift
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

import XCTest

class UnarchiverTests: XCTestCase {

    func testUnarchivingDownloadItem() throws {
        let item = DownloadItem()
        item.filename = "Test"
        item.size = 100

        // NSKeyedArchiver without secure coding (deprecated; macOS 10.12 only)
        var data = NSKeyedArchiver.archivedData(withRootObject: item)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? DownloadItem)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))

        // NSKeyedArchiver with secure coding (macOS 10.13+)
        data = try NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: false)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? DownloadItem)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))

        data = try NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: true)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? DownloadItem)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))
    }

    func testUnarchivingField() throws {
        let field = Field()
        field.name = "Name"
        field.displayName = "Display Name"
        field.sqlField = "SQL Field"
        field.type = .string
        field.isVisible = true

        // NSKeyedArchiver without secure coding (deprecated; macOS 10.12 only)
        var data = NSKeyedArchiver.archivedData(withRootObject: field)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? Field)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))

        // NSKeyedArchiver with secure coding (macOS 10.13+)
        data = try NSKeyedArchiver.archivedData(withRootObject: field, requiringSecureCoding: false)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? Field)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))

        data = try NSKeyedArchiver.archivedData(withRootObject: field, requiringSecureCoding: true)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? Field)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))
    }

    func testUnarchivingSearchMethod() throws {
        let method = try XCTUnwrap(SearchMethod.allArticles)

        // NSKeyedArchiver without secure coding (deprecated; macOS 10.12 only)
        var data = NSKeyedArchiver.archivedData(withRootObject: method)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? SearchMethod)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))

        // NSKeyedArchiver with secure coding (macOS 10.13+)
        data = try NSKeyedArchiver.archivedData(withRootObject: method, requiringSecureCoding: false)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? SearchMethod)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))

        var unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        XCTAssertNotNil(unarchiver.decodeObject(of: SearchMethod.self, forKey: NSKeyedArchiveRootObjectKey))

        data = try NSKeyedArchiver.archivedData(withRootObject: method, requiringSecureCoding: true)
        XCTAssertNotNil(NSKeyedUnarchiver.unarchiveObject(with: data) as? SearchMethod)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))

        unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        XCTAssertNotNil(unarchiver.decodeObject(of: SearchMethod.self, forKey: NSKeyedArchiveRootObjectKey))
    }

}
