//
//  DirectoryMonitorTests.swift
//  Vienna Tests
//
//  Copyright 2017 Eitot
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

@testable import Vienna
import XCTest

class DirectoryMonitorTests: XCTestCase {

    // MARK: Test objects

    var monitor: DirectoryMonitor?

    var hasHandlerBeenCalled = false

    lazy var handler: () -> Void = { [weak self] in
        guard self?.hasHandlerBeenCalled == false else {
            XCTFail("The handler has been called more often than expected")
            return
        }

        self?.hasHandlerBeenCalled = true
        self?.testExpectation?.fulfill()
    }

    let timeout: TimeInterval = 4

    // MARK: Test cycle

    var testExpectation: XCTestExpectation?

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Set the test expectation.
        testExpectation = expectation(description: "The monitor's event handler is called")

        // Create the temp directory.
        tempDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: fileManager.applicationScriptsDirectory, create: true)

        // Create the monitor.
        monitor = DirectoryMonitor(directories: [tempDirectory])
    }

    override func tearDownWithError() throws {
        // Deinitialize the monitor and reset the failsafe.
        monitor = nil
        hasHandlerBeenCalled = false

        // Delete the temp directory.
        try fileManager.removeItem(at: tempDirectory)

        // Unset the test expectation.
        testExpectation = nil

        try super.tearDownWithError()
    }

    // MARK: Test methods

    func testCreatingFile() {
        // Start monitoring.
        XCTAssertNoThrow(try monitor?.start(eventHandler: handler))

        // Create a file and observe the changes.
        let file = tempDirectory.appendingPathComponent("File 1")
        fileManager.createFile(atPath: file.path, contents: nil)

        // Make sure that there is exactly one file.
        XCTAssertEqual(tempDirectoryItemCount, 1)

        // Wait for the test result.
        waitForExpectations(timeout: timeout)
    }

    func testRenamingFile() {
        // Create a file.
        let file = tempDirectory.appendingPathComponent("File 1")
        fileManager.createFile(atPath: file.path, contents: nil)

        // Make sure that there is exactly one file.
        XCTAssertEqual(tempDirectoryItemCount, 1)

        // Start monitoring.
        XCTAssertNoThrow(try monitor?.start(eventHandler: handler))

        // Rename the file and observe the changes.
        let renamedFile = tempDirectory.appendingPathComponent("File 2")
        XCTAssertNoThrow(try fileManager.moveItem(at: file, to: renamedFile))

        // Make sure that there is still exactly one file.
        XCTAssertEqual(tempDirectoryItemCount, 1)

        // Wait for the test result.
        waitForExpectations(timeout: timeout)
    }

    func testEditingFile() {
        // The file data for one of the files.
        guard let fileData = "Data".data(using: .unicode) else {
            XCTFail("Failed to create data blob")
            return
        }

        // Create two files.
        let file1 = tempDirectory.appendingPathComponent("File 1")
        let file2 = tempDirectory.appendingPathComponent("File 2")
        fileManager.createFile(atPath: file1.path, contents: nil)
        fileManager.createFile(atPath: file2.path, contents: fileData)

        // Make sure that there are two files.
        XCTAssertEqual(tempDirectoryItemCount, 2)

        // Make sure that the content of file 1 and the variable are different.
        XCTAssertNotEqual(fileManager.contents(atPath: file1.path), fileData)

        // Start monitoring.
        XCTAssertNoThrow(try monitor?.start(eventHandler: handler))

        // Replace the contents of file 1 with the contents of file 2.
        XCTAssertNoThrow(try fileManager.replaceItem(at: file1, withItemAt: file2, backupItemName: nil, resultingItemURL: nil))

        // Make sure that the content of file 1 is now the same as the variable.
        XCTAssertEqual(fileManager.contents(atPath: file1.path), fileData)

        // Wait for the test result.
        waitForExpectations(timeout: timeout)
    }

    func testRemovingFile() {
        // Create a file.
        let file = tempDirectory.appendingPathComponent("File 1")
        fileManager.createFile(atPath: file.path, contents: nil)

        // Make sure that there is exactly one file.
        XCTAssertEqual(tempDirectoryItemCount, 1)

        // Start monitoring.
        XCTAssertNoThrow(try monitor?.start(eventHandler: handler))

        // Delete the file and observe the changes.
        XCTAssertNoThrow(try fileManager.removeItem(at: file))

        // Make sure that there is no file left.
        XCTAssertEqual(tempDirectoryItemCount, 0)

        // Wait for the test result.
        waitForExpectations(timeout: timeout)
    }

    // MARK: Test utilities

    let fileManager = FileManager.default

    var tempDirectory: URL!

    var tempDirectoryItemCount: Int {
        return (try? fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil))?.count ?? -1
    }

}
