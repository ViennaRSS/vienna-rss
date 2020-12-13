//
//  BrowserContextMenuDelegate.swift
//  Vienna
//
//  Copyright 2020 Tassilo Karge
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

import Foundation

public protocol BrowserContextMenuDelegate: AnyObject {
    func contextMenuItemsFor(purpose: WKWebViewContextMenuContext, existingMenuItems: [NSMenuItem]) -> [NSMenuItem]
}

public enum WKWebViewContextMenuContext {
    case page(url: URL)
    case link(_ url: URL)
    case picture(_ image: URL)
    case pictureLink(image: URL, link: URL)
    case text(_ text: String)
}

extension NSUserInterfaceItemIdentifier {
    static let WKMenuItemOpenLinkInBackground = NSUserInterfaceItemIdentifier("WKMenuItemIdentifierOpenLinkInBackground")
    static let WKMenuItemOpenLinkInSystemBrowser = NSUserInterfaceItemIdentifier("WKMenuItemIdentifierOpenLinkInSystemBrowser")
}
