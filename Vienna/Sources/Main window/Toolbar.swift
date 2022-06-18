//
//  Toolbar.swift
//  Vienna
//
//  Copyright 2022 Eitot
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

@objc(VNAToolbar)
class Toolbar: NSToolbar {

    // Contrary to Apple's documentation, toolbar items are not validated if
    // text-only mode is used. This affects toolbar items that do not have a
    // menu, currently only ButtonToolbarItem.
    override func validateVisibleItems() {
        guard displayMode == .labelOnly else {
            super.validateVisibleItems()
            return
        }

        for item in visibleItems ?? [] where item is ButtonToolbarItem {
            item.validate()
        }
    }

}
