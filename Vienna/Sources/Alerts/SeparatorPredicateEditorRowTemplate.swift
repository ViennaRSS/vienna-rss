//
//  SeparatorPredicateEditorRowTemplate.swift
//  Vienna
//
//  Copyright 2022 Eitot
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

@objc(VNASeparatorPredicateEditorRowTemplate)
class SeparatorPredicateEditorRowTemplate: NSPredicateEditorRowTemplate {

    private let separatorPopUpButton = {
        let popUpButton = NSPopUpButton()
        popUpButton.menu?.addItem(.separator())
        return popUpButton
    }()

    // NSPopButton is treated differently by NSPredicateEditor. It will extract
    // the menu items and merge them into a pop-up button.
    override var templateViews: [NSView] {
        return [separatorPopUpButton]
    }

    // Returning 0 ensures that this row template is never used for displaying
    // predicates.
    override func match(for predicate: NSPredicate) -> Double {
        return 0.0
    }

}
