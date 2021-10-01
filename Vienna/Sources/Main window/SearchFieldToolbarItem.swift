//
//  SearchFieldToolbarItem.swift
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

/// A toolbar item with a search field as its view.
class SearchFieldToolbarItem: NSToolbarItem {

    // Assign the item's target to the menu-form representation.
    override var target: AnyObject? {
        didSet {
            if view is NSSearchField {
                menuFormRepresentation?.target = target
            }
        }
    }

    // Assign the item's action to the menu-form representation.
    override var action: Selector? {
        didSet {
            if view is NSSearchField {
                menuFormRepresentation?.action = action
            }
        }
    }

}
