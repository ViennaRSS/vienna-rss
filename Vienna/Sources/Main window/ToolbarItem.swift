//
//  ToolbarItem.swift
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

@available(macOS, deprecated: 11)
@objc(VNAToolbarItem)
class ToolbarItem: NSToolbarItem {

    @available(*, unavailable, message: "Use Interface Builder")
    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        if #unavailable(macOS 11) {
            // As of macOS 10.15, toolbar items with the isBordered property set
            // will have a button appearance. However, setting this property in
            // Interface Builder will only work in macOS 11 and newer.
            isBordered = true

            // In macOS 10.15, toolbar items should have a uniform size.
            minSize = NSToolbarItem.defaultSize
            maxSize = NSToolbarItem.defaultSize
        }
    }
}

extension NSToolbarItem {

    @available(macOS, deprecated: 11)
    static let defaultSize = NSSize(width: 40.0, height: 24.0)
}
