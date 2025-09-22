//
//  PopUpButtonToolbarItem.swift
//  Vienna
//
//  Copyright 2017, 2025 Eitot
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
@available(macOS, obsoleted: 10.15, message: "Use NSMenuToolbarItem instead")
@objc(VNAPopUpButtonToolbarItem)
class PopUpButtonToolbarItem: NSToolbarItem {

    private let popUpButton: NSPopUpButton

    private var popUpButtonCell: NSPopUpButtonCell! {
        popUpButton.cell as? NSPopUpButtonCell
    }

    override init(itemIdentifier: NSToolbarItem.Identifier) {
        let popUpButton = NSPopUpButton()
        popUpButton.pullsDown = true
        popUpButton.bezelStyle = .toolbar
        self.popUpButton = popUpButton
        super.init(itemIdentifier: itemIdentifier)
        view = popUpButton
        minSize = NSSize(width: 41, height: 25)
        maxSize = NSSize(width: 41, height: 28)
        autovalidates = false
    }

    var menu: NSMenu {
        get {
            popUpButton.menu!
        }
        set {
            popUpButton.menu = newValue
            // Pull-down pop-up buttons hide the first menu item.
            popUpButton.menu?.items.first?.isHidden = false
            setUpMenuFormRepresentation()
        }
    }

    override var label: String {
        didSet {
            // Setting the label after the view is set clears the submenu from
            // the menu-form representation.
            setUpMenuFormRepresentation()
        }
    }

    override var image: NSImage? {
        get {
            popUpButtonCell.menuItem?.image
        }
        set {
            popUpButtonCell.usesItemFromMenu = false
            let menuItem = NSMenuItem()
            menuItem.title = ""
            menuItem.image = newValue
            popUpButtonCell.menuItem = menuItem
        }
    }

    private func setUpMenuFormRepresentation() {
        guard let menuFormRepresentation else {
            return
        }
        // Assign the pop-up button's menu to the menu-form representation.
        menuFormRepresentation.submenu = popUpButton.menu
        // Permanently enable the menu-form representation. The items
        // of the submenu are validated separately by their target.
        menuFormRepresentation.isEnabled = true
    }

}
