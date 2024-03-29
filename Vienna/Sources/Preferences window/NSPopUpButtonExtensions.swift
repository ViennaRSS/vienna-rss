//
//  NSPopUpButtonExtensions.swift
//  Vienna
//
//  Copyright 2020
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

extension NSPopUpButton {

	/// Add an item to the popup button menu with an associated image. The image is rescaled to 16x16 to fit in
	/// the menu. I've been trying to figure out how to get the actual menu item height but at a minimum, 16x16
	/// is the conventional size for a 'small' document icon. So I'm OK with this for now.
	@objc
	func addItem(withTitle title: String, image: NSImage) {
		let newItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
		image.size = NSSize(width: 16, height: 16)
		newItem.image = image
		self.menu?.addItem(newItem)
	}

}
