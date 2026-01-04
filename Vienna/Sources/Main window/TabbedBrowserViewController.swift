//
//  TabbedBrowserViewController.swift
//  Vienna
//
//  Copyright 2018 Tassilo Karge
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
import MMTabBarView
import WebKit

class TabbedBrowserViewController: NSViewController, RSSSource {

    @IBOutlet private(set) weak var tabBar: MMTabBarView? {
        didSet {
            guard let tabBar = self.tabBar else {
                return
            }
            tabBar.setStyleNamed("Mojave")
            tabBar.onlyShowCloseOnHover = true
            tabBar.canCloseOnlyTab = false
            tabBar.disableTabClose = false
            tabBar.allowsBackgroundTabClosing = true
            tabBar.hideForSingleTab = true
            tabBar.showAddTabButton = true
            tabBar.buttonMinWidth = 120
            tabBar.useOverflowMenu = true
            tabBar.automaticallyAnimates = true
            // TODO: figure out what this property means
            tabBar.allowsScrubbing = true
        }
    }

    @IBOutlet private(set) weak var tabView: NSTabView?

    /// The tab view item configured with the view that shall be in the first
    /// fixed (e.g. bookmarks). This method will set the primary tab the first
    /// time it is called.
    var primaryTab: NSTabViewItem? {
        didSet {
            // Temove from tabView if there was a prevous primary tab
            if let primaryTab = oldValue {
                self.closeTab(primaryTab)
            }
            if let primaryTab = self.primaryTab {
                tabView?.insertTabViewItem(primaryTab, at: 0)
                tabBar?.select(primaryTab)
            }
        }
    }

    var restoredTabs = false

    /// Stack to track recently closed tabs for cmd+shift+t functionality
    private var recentlyClosedTabs: [(url: URL, title: String?)] = []

    /// Check if there are any closed tabs available for reopening
    var hasClosedTabs: Bool {
        return !recentlyClosedTabs.isEmpty
    }

    var activeTab: (any Tab)? {
        tabView?.selectedTabViewItem?.viewController as? any Tab
    }

    var browserTabCount: Int {
        tabView?.numberOfTabViewItems ?? 0
    }

    weak var rssSubscriber: (any RSSSubscriber)? {
        didSet {
            for source in tabView?.tabViewItems ?? [] {
                (source as? any RSSSource)?.rssSubscriber = self.rssSubscriber
            }
        }
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        guard
            let tabBar = coder.decodeObject(of: MMTabBarView.self, forKey: "tabBar"),
            let tabView = coder.decodeObject(of: NSTabView.self, forKey: "tabView"),
            let primaryTab = coder.decodeObject(of: NSTabViewItem.self, forKey: "primaryTab")
        else { return nil }
        self.tabBar = tabBar
        self.tabView = tabView
        self.primaryTab = primaryTab
        super.init(coder: coder)
    }

    override func encode(with aCoder: NSCoder) {
        aCoder.encode(tabBar, forKey: "tabBar")
        aCoder.encode(tabBar, forKey: "tabView")
        aCoder.encode(tabBar, forKey: "primaryTab")
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if !restoredTabs {
            // Defer to avoid loading first tab, because primary tab is set
            // after view load.
            restoreTabs()
            restoredTabs = true
        }
    }

    func restoreTabs() {
        guard let tabLinks = Preferences.standard.array(forKey: "TabList") as? [String] else {
            return
        }

        let tabTitles = Preferences.standard.object(forKey: "TabTitleDict") as? [String: String]

        for urlString in tabLinks {
            guard let url = URL(string: urlString) else {
                continue
            }
            let tab = createNewTab(url, inBackground: true, load: false) as? BrowserTab
            tab?.title = tabTitles?[urlString]
        }
    }

    func saveOpenTabs() {

        let tabsOptional = tabBar?.tabView.tabViewItems.compactMap { $0.viewController as? BrowserTab }
        guard let tabs = tabsOptional else {
            return
        }

        let tabLinks = tabs.compactMap { $0.tabUrl?.absoluteString }
        let tabTitleList: [(String, String)] = tabs.filter {
            $0.tabUrl != nil && $0.title != nil
        }.map {
            ($0.tabUrl?.absoluteString ?? "", $0.title ?? "")
        }
        let tabTitles = Dictionary(tabTitleList) { $1 }

        Preferences.standard.setArray(tabLinks as [Any], forKey: "TabList")
        Preferences.standard.setObject(tabTitles, forKey: "TabTitleDict")
    }

    func closeTab(_ tabViewItem: NSTabViewItem) {
        self.tabBar?.close(tabViewItem)
    }
}

extension TabbedBrowserViewController: Browser {
    @discardableResult
    func createNewTab(_ url: URL?, inBackground: Bool, load: Bool) -> any Tab {
        createNewTab(url, inBackground: inBackground, load: load, insertAt: nil)
    }

    @discardableResult
    func createNewTabAfterSelected(_ url: URL?, inBackground: Bool, load: Bool) -> any Tab {
        createNewTab(url, inBackground: inBackground, load: load, insertAt: getIndexAfterSelected())
    }

    @discardableResult
    func createNewTab(_ url: URL? = nil, inBackground: Bool = false, load: Bool = false, insertAt index: Int? = nil) -> any Tab {
        let newTab = BrowserTab()
        return initNewTab(newTab, url, load, inBackground, insertAt: index)
    }

    private func initNewTab(_ newTab: BrowserTab, _ url: URL?, _ load: Bool, _ inBackground: Bool, insertAt index: Int? = nil) -> any Tab {
        newTab.rssSubscriber = self.rssSubscriber

        let newTabViewItem = TitleChangingTabViewItem(viewController: newTab)
        newTabViewItem.hasCloseButton = true

        // This must be executed after setup of titleChangingTabViewItem to
        // observe new title properly.
        newTab.tabUrl = url

        if load {
            newTab.loadTab()
        }

        if let index = index {
            tabView?.insertTabViewItem(newTabViewItem, at: index)
        } else {
            tabView?.addTabViewItem(newTabViewItem)
        }

        if !inBackground {
            tabBar?.select(newTabViewItem)
            if load {
                newTab.webView.becomeFirstResponder()
            } else {
                newTab.activateAddressBar()
            }
            // TODO: make first responder?
        }

        newTab.webView.contextMenuProvider = self

        // TODO: tab view order

        return newTab
    }

    func switchToPrimaryTab() {
        if self.primaryTab != nil {
            self.tabView?.selectTabViewItem(at: 0)
        }
    }

    func showPreviousTab() {
        if self.tabView?.selectedTabViewItem == primaryTab {
            self.tabView?.selectLastTabViewItem(nil)
        } else {
            self.tabView?.selectPreviousTabViewItem(nil)
        }
    }

    func showNextTab() {
        if getIndexAfterSelected() == browserTabCount {
            self.tabView?.selectFirstTabViewItem(nil)
        } else {
            self.tabView?.selectNextTabViewItem(nil)
        }
    }

    func closeActiveTab() {
        if let selectedTabViewItem = self.tabView?.selectedTabViewItem {
            self.closeTab(selectedTabViewItem)
        }
    }

    func closeAllTabs() {
        self.tabView?.tabViewItems.filter { $0 != primaryTab }
            .forEach(closeTab)
    }

    /// Reopens the most recently closed tab (cmd+shift+t functionality)
    @discardableResult
    func reopenLastClosedTab() -> Bool {
        guard !recentlyClosedTabs.isEmpty else {
            return false
        }

        let lastClosed = recentlyClosedTabs.removeLast()
        createNewTab(lastClosed.url, inBackground: false, load: true)
        return true
    }

    func getTextSelection() -> String {
        // TODO: implement
        return ""
    }

    func getActiveTabHTML() -> String {
        // TODO: implement
        return ""
    }

    func getActiveTabURL() -> URL? {
        // TODO: implement
        return URL(string: "")
    }
}

extension TabbedBrowserViewController: MMTabBarViewDelegate {
    func tabView(_ aTabView: NSTabView, shouldClose tabViewItem: NSTabViewItem) -> Bool {
        tabViewItem != primaryTab
    }

    func tabView(_ aTabView: NSTabView, willClose tabViewItem: NSTabViewItem) {
        guard let tab = tabViewItem.viewController as? any Tab else {
            return
        }

        // Track closed tab for potential reopening (cmd+shift+t)
        if let browserTab = tab as? BrowserTab,
           let url = browserTab.tabUrl,
           tabViewItem != primaryTab {
            recentlyClosedTabs.append((url: url, title: browserTab.title))
            // Limit the history to reasonable number (e.g., 20)
            if recentlyClosedTabs.count > 20 {
                recentlyClosedTabs.removeFirst()
            }
        }

        tab.closeTab()
    }

    func tabView(_ aTabView: NSTabView, selectOnClosing tabViewItem: NSTabViewItem) -> NSTabViewItem? {
        // Select tab item on the right of currently selected item. Cannot
        // select tab on the right, if selected tab is rightmost one.
        if let tabView = self.tabBar?.tabView,
           let selected = tabBar?.selectedTabViewItem, selected == tabViewItem,
           tabViewItem != tabView.tabViewItems.last,
           let indexToSelect = tabView.tabViewItems.firstIndex(of: selected)?.advanced(by: 1) {
            return tabView.tabViewItems[indexToSelect]
        } else {
            // Default (left of currently selected item / no change if deleted
            // item not selected)
            return nil
        }
    }

    func tabView(_ aTabView: NSTabView, menuFor tabViewItem: NSTabViewItem) -> NSMenu {
        // TODO: return menu corresponding to browser or primary tab view item
        return NSMenu()
    }

    func tabView(_ aTabView: NSTabView, shouldDrag tabViewItem: NSTabViewItem, in tabBarView: MMTabBarView) -> Bool {
        tabViewItem != primaryTab
    }

    func tabView(_ aTabView: NSTabView, validateDrop sender: any NSDraggingInfo, proposedItem tabViewItem: NSTabViewItem, proposedIndex: UInt, in tabBarView: MMTabBarView) -> NSDragOperation {
        proposedIndex != 0 ? [.every] : []
    }

    func tabView(_ aTabView: NSTabView, validateSlideOfProposedItem tabViewItem: NSTabViewItem, proposedIndex: UInt, in tabBarView: MMTabBarView) -> NSDragOperation {
        (tabViewItem != primaryTab && proposedIndex != 0) ? [.every] : []
    }

    func addNewTab(to aTabView: NSTabView) {
        self.createNewTab()
    }

    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        let tab = (tabViewItem?.viewController as? BrowserTab)
        if let loaded = tab?.loadedTab, !loaded {
            tab?.loadTab()
        }
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        NotificationCenter.default.post(name: .tabChanged, object: tabViewItem?.view)
    }

    func tabViewDidChangeNumberOfTabViewItems(_ tabView: NSTabView) {
        NotificationCenter.default.post(name: .tabCountChanged, object: tabView)
    }
}

// MARK: WKUIDelegate + BrowserContextMenuDelegate

extension TabbedBrowserViewController: CustomWKUIDelegate {
    // TODO: implement functionality for alerts and maybe peek actions

    private static var contextMenuCustomizer: any BrowserContextMenuDelegate = WebKitContextMenuCustomizer()

    func contextMenuItemsFor(purpose: WKWebViewContextMenuContext, existingMenuItems: [NSMenuItem]) -> [NSMenuItem] {
        // specific customization of menuItems may be added here
        // using the following commented out construct
        //     var menuItems = existingMenuItems
        //        ...
        //     return TabbedBrowserViewController.contextMenuCustomizer.contextMenuItemsFor(purpose: purpose, existingMenuItems: menuItems)
        return TabbedBrowserViewController.contextMenuCustomizer.contextMenuItemsFor(purpose: purpose, existingMenuItems: existingMenuItems)
    }

    @objc
    func processMenuItem(_ menuItem: NSMenuItem) {
        guard let url = menuItem.representedObject as? URL else {
            return
        }
        switch menuItem.identifier {
        case NSUserInterfaceItemIdentifier.WKMenuItemOpenLinkInBackground:
            self.createNewTabAfterSelected(url, inBackground: true, load: true)
        case NSUserInterfaceItemIdentifier.WKMenuItemOpenLinkInNewWindow, NSUserInterfaceItemIdentifier.WKMenuItemOpenImageInNewWindow, NSUserInterfaceItemIdentifier.WKMenuItemOpenMediaInNewWindow:
            self.createNewTabAfterSelected(url, inBackground: false, load: true)
        case NSUserInterfaceItemIdentifier.WKMenuItemOpenLinkInSystemBrowser:
            NSApp.appController.openURL(inDefaultBrowser: url)
        case NSUserInterfaceItemIdentifier.WKMenuItemDownloadImage, NSUserInterfaceItemIdentifier.WKMenuItemDownloadMedia, NSUserInterfaceItemIdentifier.WKMenuItemDownloadLinkedFile:
            DownloadManager.shared.downloadFile(fromURL: url.absoluteString)
        default:
            break
        }
    }

    private func getIndexAfterSelected() -> Int {
        guard let tabView = tabView, let selectedItem = tabView.selectedTabViewItem else {
            return 0
        }
        let selectedIndex = tabView.tabViewItems.firstIndex(of: selectedItem) ?? 0
        return tabView.tabViewItems.index(after: selectedIndex)
    }
}
