//
//  ButtonToolbarItem.swift
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

/// A toolbar item with a button as its view. The toolbar item responds to
/// validation requests.
@objc(VNAButtonToolbarItem)
class ButtonToolbarItem: NSToolbarItem {

    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)

        let button = NSButton()
        button.bezelStyle = .toolbar
        // Ensure that the toolbar item has the same width as the other toolbar
        // items in macOS 10.15.
        if #unavailable(macOS 11) {
            let width = NSToolbarItem.defaultSize.width - 2.0
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        view = button

        // The default menuFormRepresentation cannot be used, because it will
        // reset the toolbar's display mode. However, the toolbar will validate
        // and enable a custom menu item, provided it implements the action.
        let menuItem = NSMenuItem(
            title: "",
            action: #selector(menuFormRepresentationClicked(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self
        menuFormRepresentation = menuItem
    }

    override var label: String {
        didSet {
            menuFormRepresentation?.title = label
        }
    }

    override var image: NSImage? {
        didSet {
            if #available(macOS 26, *) {
                menuFormRepresentation?.image = image
            }
        }
    }

    var button: NSButton? {
        get {
            view as? NSButton
        }
        set {
            view = newValue
        }
    }

    // The default implementation of this method does nothing for toolbar items
    // with a custom view. Overriding this will allow any responder object to
    // validate the toolbar item.
    override func validate() {
        guard let action else {
            isEnabled = false
            return
        }

        switch NSApp.target(forAction: action, to: target, from: self) {
        case let validator as any NSToolbarItemValidation:
            isEnabled = validator.validateToolbarItem(self)
        default:
            isEnabled = false
        }
    }

    // This method mimics a private method of NSToolbarItem that is used by
    // default menuFormRepresentation objects. NSToolbarItem conforms to the
    // NSMenuItemValidation protocol and will validate the menu item for this
    // action, presumably referencing the isEnabled property.
    @objc
    private func menuFormRepresentationClicked(_ menuItem: NSMenuItem) {
        if let action, menuItem == menuFormRepresentation {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
}
