//
//  MainWindow.swift
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

final class MainWindow: NSWindow {

    // This workaround assures that the title of the toggleable menu item
    // reflects the toolbar's visibility state. The default implementation
    // does not seem to work with all localizations.
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleToolbarShown(_:)) {
            guard let toolbar = toolbar else {
                return false
            }

            if toolbar.isVisible {
                menuItem.title = NSLocalizedString("Hide Toolbar", comment: "Title of a menu item")
            } else {
                menuItem.title = NSLocalizedString("Show Toolbar", comment: "Title of a menu item")
            }

            return true
        } else {
            return super.validateMenuItem(menuItem)
        }
    }

}
