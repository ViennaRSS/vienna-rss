//
//  TitleChangingTabViewItem.swift
//  Vienna
//
//  Copyright 2018
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
// Swift version of https://github.com/thomasguenzel/blog/blob/master/NSTabViewItem_Title/GNTabViewItem.m
//

import Cocoa

class TitleChangingTabViewItem: NSTabViewItem {

    var titleObservation: NSKeyValueObservation?

    override var viewController: NSViewController? {
        didSet {
            super.viewController = viewController
            titleObservation?.invalidate()
            titleObservation = self.viewController?.observe(\.title, options: .new) { [weak self] _, change in
                self?.label = (change.newValue ?? "") ?? ""
            }
        }
    }

    deinit {
        print("Title changing tabviewitem deinited")
    }
}
