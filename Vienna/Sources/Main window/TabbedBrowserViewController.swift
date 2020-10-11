//
//  TabbedBrowserViewController.swift
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

import Cocoa
import MMTabBarView

@available(OSX 10.10, *)
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
            //TODO: figure out what this property means
            tabBar.allowsScrubbing = true
        }
    }

    @IBOutlet private(set) weak var tabView: NSTabView?

    /// The browser can have a fixed first tab (e.g. bookmarks).
    /// This method will set the primary tab the first time it is called
    /// - Parameter tabViewItem: the tab view item configured with the view that shall be in the first fixed tab.
    var primaryTab: NSTabViewItem? {
        didSet {
            //remove from tabView if there was a prevous primary tab
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

    var activeTab: Tab? {
        tabView?.selectedTabViewItem?.viewController as? Tab
    }

    var browserTabCount: Int {
        tabView?.numberOfTabViewItems ?? 0
    }

    weak var rssSubscriber: RSSSubscriber? {
        didSet {
            for source in tabView?.tabViewItems ?? [] {
                (source as? RSSSource)?.rssSubscriber = self.rssSubscriber
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
            //defer to avoid loading first tab, because primary tab is set after view load
            restoreTabs()
            restoredTabs = true
        }
    }

    func restoreTabs() {
        let tabLinks = Preferences.standard.array(forKey: "TabList") as? [String]
        let tabTitles = Preferences.standard.object(forKey: "TabTitleDict") as? [String: String]

        for i in 0..<(tabLinks?.count ?? 0) {
            guard let urlString = tabLinks?[i], let url = URL(string: urlString) else {
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

        Preferences.standard.save()
    }

    func closeTab(_ tabViewItem: NSTabViewItem) {
        guard let tabView = self.tabView else {
            return
        }
        self.tabBar?.delegate?.tabView?(tabView, willClose: tabViewItem)
        self.tabView?.removeTabViewItem(tabViewItem)
        self.tabBar?.delegate?.tabView?(tabView, didClose: tabViewItem)
    }
}

extension TabbedBrowserViewController: Browser {
    func createNewTab(_ url: URL?, inBackground: Bool, load: Bool) -> Tab {
        return createNewTab(url, inBackground: inBackground, load: load, insertAt: nil)
    }

    func createNewTab(_ request: URLRequest, config: WKWebViewConfiguration, inBackground: Bool, insertAt index: Int? = nil) -> Tab {
        let newTab = BrowserTab(request, config: config)
        return initNewTab(newTab, request.url, false, inBackground, insertAt: index)
    }

    func createNewTab(_ url: URL? = nil, inBackground: Bool = false, load: Bool = false, insertAt index: Int? = nil) -> Tab {
        let newTab = BrowserTab()
        return initNewTab(newTab, url, load, inBackground, insertAt: index)
    }

    private func initNewTab(_ newTab: BrowserTab, _ url: URL?, _ load: Bool, _ inBackground: Bool, insertAt index: Int? = nil) -> Tab {
        newTab.rssSubscriber = self.rssSubscriber

        let newTabViewItem = TitleChangingTabViewItem(viewController: newTab)
        newTabViewItem.hasCloseButton = true

        //this must be executed after setup of titleChangingTabViewItem to observe new title properly
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
			//TODO: make first responder?
		}

        newTab.webView.uiDelegate = self

        newTab.webView.contextMenuProvider = self

        //TODO: tab view order

        return newTab
    }

    func switchToPrimaryTab() {
        if self.primaryTab != nil {
            self.tabView?.selectTabViewItem(at: 0)
        }
    }

	func showPreviousTab() {
        self.tabView?.selectPreviousTabViewItem(nil)
    }

	func showNextTab() {
        self.tabView?.selectNextTabViewItem(nil)
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

    func getTextSelection() -> String {
        //TODO: implement
        return ""
    }

    func getActiveTabHTML() -> String {
        //TODO: implement
        return ""
    }

    func getActiveTabURL() -> URL? {
        //TODO: implement
        return URL(string: "")
    }
}

@available(OSX 10.10, *)
extension TabbedBrowserViewController: MMTabBarViewDelegate {
    func tabView(_ aTabView: NSTabView, shouldClose tabViewItem: NSTabViewItem) -> Bool {
        tabViewItem != primaryTab
    }

    func tabView(_ aTabView: NSTabView, willClose tabViewItem: NSTabViewItem) {
        guard let tab = tabViewItem.viewController as? Tab else {
            return
        }
        tab.stopLoadingTab()
        tab.tabUrl = URL(string: "about:blank")
        tab.loadTab()
    }

    func tabView(_ aTabView: NSTabView, menuFor tabViewItem: NSTabViewItem) -> NSMenu {
        //TODO: return menu corresponding to browser or primary tab view item
        return NSMenu()
    }

    func tabView(_ aTabView: NSTabView, shouldDrag tabViewItem: NSTabViewItem, in tabBarView: MMTabBarView) -> Bool {
        tabViewItem != primaryTab
    }

    func tabView(_ aTabView: NSTabView, validateDrop sender: NSDraggingInfo, proposedItem tabViewItem: NSTabViewItem, proposedIndex: UInt, in tabBarView: MMTabBarView) -> NSDragOperation {
        proposedIndex != 0 ? [.every] : []
    }

    func tabView(_ aTabView: NSTabView, validateSlideOfProposedItem tabViewItem: NSTabViewItem, proposedIndex: UInt, in tabBarView: MMTabBarView) -> NSDragOperation {
        (tabViewItem != primaryTab && proposedIndex != 0) ? [.every] : []
    }

    func addNewTab(to aTabView: NSTabView) {
        _ = self.createNewTab()
    }

    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        let tab = (tabViewItem?.viewController as? BrowserTab)
        if let loaded = tab?.loadedTab, !loaded {
            tab?.loadTab()
        }
    }
}

@available(OSX 10.10, *)
extension TabbedBrowserViewController: CustomWKUIDelegate {
	//TODO: implement functionality for alerts and maybe peek actions

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let newTab = self.createNewTab(navigationAction.request, config: configuration, inBackground: false, insertAt: getIndexAfterSelected())
        return (newTab as? BrowserTab)?.webView
    }

    func contextMenuItemsFor(purpose: WKWebViewContextMenuContext, existingMenuItems: [NSMenuItem]) -> [NSMenuItem] {
        var menuItems = existingMenuItems
        switch purpose {
        case .page(url: _):
            break
        case .link(let url):
            addLinkMenuCustomizations(&menuItems, url)
        case .picture(_):
            break
        case .pictureLink(image: _, link: let link):
            addLinkMenuCustomizations(&menuItems, link)
        case .text(_):
            break
        }
        return menuItems
    }

    private func addLinkMenuCustomizations(_ menuItems: inout [NSMenuItem], _ url: (URL)) {
        if let index = menuItems.firstIndex(where: { $0.identifier?.rawValue == "WKMenuItemIdentifierOpenLinkInNewWindow" }) {
            menuItems[index].title = "Open link in new tab"

            let openInBackgroundItem = NSMenuItem(title: "Open link in background", action: #selector(openLinkInBackground(menuItem:)), keyEquivalent: "")
            openInBackgroundItem.identifier = .WKMenuItemIdentifierOpenLinkInBackground
            openInBackgroundItem.representedObject = url
            menuItems.insert(openInBackgroundItem, at: menuItems.index(after: index))

            let openInDefaultBrowserItem = NSMenuItem(title: "Open link in [Default Browser Name]", action: #selector(openLinkInDefaultBrowser(menuItem:)), keyEquivalent: "")
            openInDefaultBrowserItem.identifier = .WKMenuItemIdentifierOpenLinkInSystemBrowser
            openInDefaultBrowserItem.representedObject = url
            menuItems.insert(openInDefaultBrowserItem, at: menuItems.index(after: index))
        }
    }

    @objc
    func openLinkInBackground(menuItem: NSMenuItem) {
        if let url = menuItem.representedObject as? URL {
            _ = self.createNewTab(url, inBackground: true, load: true, insertAt: getIndexAfterSelected())
        }
    }

    @objc
    func openLinkInDefaultBrowser(menuItem: NSMenuItem) {
        if let url = menuItem.representedObject as? URL {
            // TODO: open in default browser
        }
    }

    private func getIndexAfterSelected() -> Int {
        guard let tabView = tabView, let selectedItem = tabView.selectedTabViewItem else { return 0 }
        let selectedIndex = tabView.tabViewItems.firstIndex(of: selectedItem) ?? 0
        return tabView.tabViewItems.index(after: selectedIndex)
    }
}
