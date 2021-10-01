//
//  PopUpButtonToolbarItem.swift
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

/// A toolbar item with a pop-up button as its view.
class PopUpButtonToolbarItem: NSToolbarItem {

    // Assign the pop-up button's menu to the menu-form representation.
    override var view: NSView? {
        didSet {
            if let popupButton = view as? NSPopUpButton {
                menuFormRepresentation?.submenu = popupButton.menu

                // Unsetting target and action will ascertain that the menu is
                // always enabled.
                menuFormRepresentation?.target = nil
                menuFormRepresentation?.action = nil
            }
        }
    }

    // Permanently enable the menu-form representation. The submenu's items are
    // validated separately by their target.
    override func validate() {
        super.validate()

        if view is NSPopUpButton {
            menuFormRepresentation?.isEnabled = true
        }
    }

}
