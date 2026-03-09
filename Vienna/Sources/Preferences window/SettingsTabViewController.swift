//
//  SettingsTabViewController.swift
//  Vienna
//
//  Copyright 2024 Eitot
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

// This class exists to provide fallback images for several toolbar items of the
// settings window.
@objc(VNASettingsTabViewController)
class SettingsTabViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard #unavailable(macOS 15) else {
            return
        }

        tabViewItems.forEach { item in
            updateImage(forTabViewItem: item)
        }
    }

    @available(macOS, obsoleted: 15)
    private func updateImage(forTabViewItem tabViewItem: NSTabViewItem) {
        // macOS 11 to 14
        if #available(macOS 11, *) {
            if tabViewItem.identifier as? String == "syncing" {
                tabViewItem.image = NSImage(
                    systemSymbolName: "arrow.triangle.2.circlepath",
                    accessibilityDescription: nil
                )
            }
            return
        }

        // macOS 10.13 to 10.15
        switch tabViewItem.identifier as? String {
        case "general":
            tabViewItem.image = NSImage(named: NSImage.preferencesGeneralName)
        case "syncing":
            tabViewItem.image = NSImage(resource: .sync)
        case "updates":
            tabViewItem.image = NSImage(named: NSImage.networkName)
        case "advanced":
            tabViewItem.image = NSImage(named: NSImage.advancedName)
        default:
            return
        }
    }

}
