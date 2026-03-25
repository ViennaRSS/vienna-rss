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

        var data = try NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: false)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: DownloadItem.self, from: data))

        data = try NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: true)
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

        var data = try NSKeyedArchiver.archivedData(withRootObject: field, requiringSecureCoding: false)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))

        data = try NSKeyedArchiver.archivedData(withRootObject: field, requiringSecureCoding: true)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: Field.self, from: data))
    }

    func testUnarchivingSearchMethod() throws {
        let method = try XCTUnwrap(SearchMethod.allArticles)

        var data = try NSKeyedArchiver.archivedData(withRootObject: method, requiringSecureCoding: false)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))

        var unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        XCTAssertNotNil(unarchiver.decodeObject(of: SearchMethod.self, forKey: NSKeyedArchiveRootObjectKey))

        data = try NSKeyedArchiver.archivedData(withRootObject: method, requiringSecureCoding: true)
        XCTAssertNotNil(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))
        XCTAssertNoThrow(try NSKeyedUnarchiver.unarchivedObject(ofClass: SearchMethod.self, from: data))

        unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        XCTAssertNotNil(unarchiver.decodeObject(of: SearchMethod.self, forKey: NSKeyedArchiveRootObjectKey))
    }

}
