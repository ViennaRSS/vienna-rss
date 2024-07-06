//
//  PreferenceTabViewItem.swift
//  Vienna
//
//  Copyright 2020 Eitot
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
// preferences window.
// 
// Rather than adding copies of the standard images provided by Apple, they are
// instead referenced by name. The remaining toolbar items use fallback images
// in the asset catalog.
@available(macOS, obsoleted: 11.0)
class PreferenceTabViewItem: NSTabViewItem {

    override func awakeFromNib() {
        super.awakeFromNib()

        if #available(macOS 11.0, *) {
            return
        }

        switch identifier as? String {
        case "general":
            image = NSImage(named: NSImage.preferencesGeneralName)
        case "updates":
            image = NSImage(named: NSImage.networkName)
        case "advanced":
            image = NSImage(named: NSImage.advancedName)
        default:
            return
        }
    }

}
