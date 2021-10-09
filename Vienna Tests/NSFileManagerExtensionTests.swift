//
//  NSFileManagerExtensionTests.swift
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

class NSFileManagerExtensionTests: XCTestCase {

    let homePath = NSHomeDirectory()
    let bundleID = Bundle.main.bundleIdentifier ?? ""

    func testApplicationScriptsPath() throws {
        let result = FileManager.default.applicationScriptsDirectory
        let fullPath = "\(homePath)/Library/Scripts/Applications/Vienna"
        XCTAssertEqual(result.path, fullPath)
    }

    func testApplicationSupportPath() throws {
        let result = FileManager.default.applicationSupportDirectory
        let fullPath = "\(homePath)/Library/Application Support/Vienna"
        XCTAssertEqual(result.path, fullPath)
    }

    func testCachesPath() throws {
        let result = FileManager.default.cachesDirectory
        let fullPath = "\(homePath)/Library/Caches/\(bundleID)"
        XCTAssertEqual(result.path, fullPath)
    }

    func testDownloadsPath() throws {
        let result = FileManager.default.downloadsDirectory
        let fullPath = "\(homePath)/Downloads"
        XCTAssertEqual(result.path, fullPath)
    }

}
