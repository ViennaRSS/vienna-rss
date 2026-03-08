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

    @available(*, unavailable, message: "Use Interface Builder")
    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Ensure that the toolbar item has the same width as the other toolbar
        // items in macOS 10.15.
        if #unavailable(macOS 11), let view {
            let width = NSToolbarItem.defaultSize.width - 2.0
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
        }

        // The default menuFormRepresentation cannot be used, because it will
        // reset the toolbar's display mode to label-only mode. However, the
        // toolbar will validate and enable a custom menu item, provided it
        // implements the action.
        let menuItem = NSMenuItem(
            title: label,
            action: #selector(menuFormRepresentationClicked(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self
        if #available(macOS 26, *) {
            menuItem.image = image
        }
        menuFormRepresentation = menuItem
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
        if let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
}
