//
//  WebKitContextMenuCustomizer.swift
//  Vienna
//
//  Copyright 2021 Tassilo Karge
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

class WebKitContextMenuCustomizer {

    static func contextMenuItemsFor(purpose: WKWebViewContextMenuContext, existingMenuItems: [NSMenuItem]) -> [NSMenuItem] {

        var menuItems = existingMenuItems
        switch purpose {
        case .page(url: _):
            break
        case .link(let url):
            addLinkMenuCustomizations(&menuItems, url)
        case .picture:
            break
        case .pictureLink(image: _, link: let link):
            addLinkMenuCustomizations(&menuItems, link)
        case .text:
            break
        }
        return menuItems
    }

    private static func addLinkMenuCustomizations(_ menuItems: inout [NSMenuItem], _ url: (URL)) {
        guard var index = menuItems.firstIndex(where: { $0.identifier == .WKMenuItemOpenLinkInNewWindow }) else {
            return
        }

        if let openInBackgroundIndex = menuItems.firstIndex(where: { $0.identifier == NSUserInterfaceItemIdentifier.WKMenuItemOpenLinkInBackground }) {
            // Swap open link in new tab and open link in background items if
            // necessary/
            let openInBackground = Preferences.standard.openLinksInBackground
            if openInBackground && index < openInBackgroundIndex
                || !openInBackground && openInBackgroundIndex < index {
                menuItems.swapAt(index, openInBackgroundIndex)
            }
            index = max(index, openInBackgroundIndex)
        }

        let defaultBrowser = getDefaultBrowser() ?? NSLocalizedString("External Browser", comment: "")
        let openInExternalBrowserTitle = NSLocalizedString("Open Link in %@", comment: "")
            .replacingOccurrences(of: "%@", with: defaultBrowser)
        let openInDefaultBrowserItem = NSMenuItem(
            title: openInExternalBrowserTitle,
            action: #selector(openLinkInDefaultBrowser(menuItem:)), keyEquivalent: "")
        openInDefaultBrowserItem.identifier = .WKMenuItemOpenLinkInSystemBrowser
        openInDefaultBrowserItem.representedObject = url
        menuItems.insert(openInDefaultBrowserItem, at: menuItems.index(after: index + 1))
    }

    @objc
    func openLinkInDefaultBrowser(menuItem: NSMenuItem) {
        if let url = menuItem.representedObject as? URL {
            NSApp.appController.openURL(inDefaultBrowser: url)
        }
    }
}
