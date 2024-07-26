//
//  PluginManagerTests.swift
//  Vienna Tests
//
//  Copyright 2024 Eitot
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

import Vienna
import XCTest

final class PluginManagerTests: XCTestCase {

    private let fileExtension = "viennaplugin"
    private let identifierKey = "Name"
    private let displayNameKey = "FriendlyName"

    private let testBundle = Bundle(for: PluginManagerTests.self)

    func testBundleWithCapitalizedInfoPlist() throws {
        let url = testBundle.url(
            forResource: "PluginBundleWithCapitalizedInfoPlist",
            withExtension: fileExtension)
        let bundleURL = try XCTUnwrap(url)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        XCTAssertNotNil(bundle.infoDictionary)
        XCTAssertNil(bundle.localizedInfoDictionary)
        let name = try XCTUnwrap(bundle.object(forInfoDictionaryKey: identifierKey) as? String)
        XCTAssert(name == "TestPlugin")
    }

    func testBundleWithLowercaseInfoPlist() throws {
        let url = testBundle.url(
            forResource: "PluginBundleWithLowercaseInfoPlist",
            withExtension: fileExtension)
        let bundleURL = try XCTUnwrap(url)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        XCTAssertNotNil(bundle.infoDictionary)
        XCTAssertNil(bundle.localizedInfoDictionary)
        let name = try XCTUnwrap(bundle.object(forInfoDictionaryKey: identifierKey) as? String)
        XCTAssert(name == "TestPlugin")
    }

    func testBundleWithoutInfoPlist() throws {
        let url = testBundle.url(
            forResource: "PluginBundleWithoutInfoPlist",
            withExtension: fileExtension)
        let bundleURL = try XCTUnwrap(url)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        XCTAssertNotNil(bundle.infoDictionary)
        XCTAssertNil(bundle.localizedInfoDictionary)
        XCTAssertNil(bundle.object(forInfoDictionaryKey: identifierKey))
    }

    func testBundleWithLocalizedInfoPlist() throws {
        let url = testBundle.url(
            forResource: "PluginBundleWithLocalizedInfoPlist",
            withExtension: fileExtension)
        let bundleURL = try XCTUnwrap(url)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        XCTAssertNotNil(bundle.infoDictionary)
        XCTAssertNotNil(bundle.localizedInfoDictionary)

        let resources = bundle.urls(forResourcesWithExtension: "plist", subdirectory: nil) ?? []
        XCTAssert(resources.count == 1)
        for resource in resources {
            print(resource.absoluteString)
        }

        if bundle.preferredLocalizations.contains("en") {
            let localizedDisplayName = try XCTUnwrap(bundle.object(forInfoDictionaryKey: displayNameKey) as? String)
            XCTAssert(localizedDisplayName == "Test Plug-In")
        }
        if bundle.preferredLocalizations.contains("de") {
            let localizedDisplayName = try XCTUnwrap(bundle.object(forInfoDictionaryKey: displayNameKey) as? String)
            XCTAssert(localizedDisplayName == "Test-Plug-In")
        }
        if bundle.preferredLocalizations.contains("fr") {
            let localizedDisplayName = try XCTUnwrap(bundle.object(forInfoDictionaryKey: displayNameKey) as? String)
            XCTAssert(localizedDisplayName == "Plugin de test")
        }
        let unlocalizedDisplayName = try XCTUnwrap(bundle.infoDictionary?[displayNameKey] as? String)
        XCTAssert(unlocalizedDisplayName == "Test Plug-In (Unlocalized)")
        let localizedIdentifier = try XCTUnwrap(bundle.object(forInfoDictionaryKey: identifierKey) as? String)
        XCTAssert(localizedIdentifier == "TestPlugin")
        let unlocalizedIdentifier = try XCTUnwrap(bundle.infoDictionary?[identifierKey] as? String)
        XCTAssert(unlocalizedIdentifier == "TestPlugin")
    }

}
