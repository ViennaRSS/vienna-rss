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

import Cocoa

class WebKitContextMenuCustomizer: BrowserContextMenuDelegate {

    func contextMenuItemsFor(purpose: WKWebViewContextMenuContext, existingMenuItems: [NSMenuItem]) -> [NSMenuItem] {

        var menuItems = existingMenuItems
        switch purpose {
        case .link(let url):
            addLinkMenuCustomizations(&menuItems, url)
        case .pictureLink(image: _, link: let link):
            addLinkMenuCustomizations(&menuItems, link)
        default:
            break
        }
        return menuItems
    }

    func addLinkMenuCustomizations(_ menuItems: inout [NSMenuItem], _ url: (URL)) {
        for index in (0...(menuItems.count - 1)).reversed() {
            let id = menuItems[index].identifier
            if id == .WKMenuItemOpenLinkInNewWindow {
                // replace "Open Link in New Window" with open link in New Tab
                menuItems[index].title = NSLocalizedString("Open Link in New Tab", comment: "")
                menuItems[index].target = nil
                menuItems[index].representedObject = url
                menuItems[index].action = #selector(processMenuItem(_:))

                // add some menu items
                let openInBackgroundTitle = NSLocalizedString("Open Link in Background", comment: "")
                let openInBackgroundItem = NSMenuItem(title: openInBackgroundTitle, action: #selector(processMenuItem(_:)), keyEquivalent: "")
                openInBackgroundItem.identifier = .WKMenuItemOpenLinkInBackground
                openInBackgroundItem.representedObject = url
                let openInBackground = Preferences.standard.openLinksInBackground
                if openInBackground {
                    menuItems.insert(openInBackgroundItem, at: index)
                } else {
                    menuItems.insert(openInBackgroundItem, at: menuItems.index(after: index))
                }

                let defaultBrowser = getDefaultBrowser() ?? NSLocalizedString("External Browser", comment: "")
                let openInExternalBrowserTitle = String(format: NSLocalizedString("Open Link in %@", comment: ""), defaultBrowser)
                let openInDefaultBrowserItem = NSMenuItem(title: openInExternalBrowserTitle,
                                                          action: #selector(processMenuItem(_:)), keyEquivalent: "")
                openInDefaultBrowserItem.identifier = .WKMenuItemOpenLinkInSystemBrowser
                openInDefaultBrowserItem.representedObject = url
                menuItems.insert(openInDefaultBrowserItem, at: menuItems.index(after: index + 1))

            }
        }
    }

    @objc
    func processMenuItem(_ menuItem: NSMenuItem) {
    // placeholder : this is never called
    // as we are not part of the responder chain
    }

}
