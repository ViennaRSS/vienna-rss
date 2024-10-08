//
//  PlugInToolbarItem.swift
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

/// A toolbar item with a button as its view.
///
/// - Note: This item should only be initialized programmatically.
@objc(VNAPlugInToolbarItem)
class PlugInToolbarItem: ButtonToolbarItem {

    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)

        let button = PlugInToolbarItemButton(frame: NSRect(x: 0, y: 0, width: 41, height: 25))
        button.bezelStyle = .toolbar
        button.toolbarItem = self
        view = button
    }

}
