//
//  RepresentingToolbarItem.swift
//  Vienna
//
//  Copyright 2026 Eitot
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

@objc(VNARepresentingToolbarItem)
class RepresentingToolbarItem: NSToolbarItem {

    @objc var representedObject: Any?

    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)

        isBordered = true
        if #unavailable(macOS 11) {
            // In macOS 10.15, toolbar items should have a uniform size.
            minSize = NSToolbarItem.defaultSize
            maxSize = NSToolbarItem.defaultSize
        }
    }

    override var image: NSImage? {
        didSet {
            if #unavailable(macOS 11) {
                // In macOS 10.15, the menu item should not have an image.
                menuFormRepresentation?.image = nil
            }
        }
    }
}
