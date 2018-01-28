//
//  ExportAccessoryViewController.swift
//  Vienna
//
//  Copyright 2017
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

import Cocoa

final class ExportAccessoryViewController: NSViewController {

    // MARK: Bindings

    @objc private dynamic var exportAllFeedsRadioButtonState: NSControl.StateValue = .on
    @objc private dynamic var preserveFoldersCheckboxButtonState: NSControl.StateValue = .on

    // MARK: Export options

    /// The export mode to use.
    @objc var mode: ExportMode {
        get {
            return exportAllFeedsRadioButtonState == .on ? .allFeeds : .selectedFeeds
        }
        set {
            exportAllFeedsRadioButtonState = newValue == .allFeeds ? .on : .off
        }
    }

    /// Whether folders should be preserved.
    @objc var preserveFolders: Bool {
        get {
            return preserveFoldersCheckboxButtonState == .on
        }
        set {
            preserveFoldersCheckboxButtonState = newValue ? .on : .off
        }
    }

    // MARK: Nested types

    @objc
    enum ExportMode: Int {
        /// All feeds should be exported.
        case allFeeds

        /// Only the currently selected feeds should be exported.
        case selectedFeeds
    }

}
