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
class TabbedBrowserViewController: NSViewController, Browser {

    @IBOutlet private(set) weak var tabBar: MMTabBarView! {
        didSet {
            self.tabBar.setStyleNamed("Mojave")
            self.tabBar.onlyShowCloseOnHover = true
            self.tabBar.canCloseOnlyTab = false
            self.tabBar.disableTabClose = false
            self.tabBar.allowsBackgroundTabClosing = true
            self.tabBar.hideForSingleTab = true
            self.tabBar.showAddTabButton = true
            self.tabBar.buttonMinWidth = 120
            self.tabBar.useOverflowMenu = true
            self.tabBar.automaticallyAnimates = true
            //TODO: figure out what this property means
            self.tabBar.allowsScrubbing = true
        }
    }

    @IBOutlet private(set) weak var tabView: NSTabView!

    /// The browser can have a fixed first tab (e.g. bookmarks).
    /// This method will set the primary tab the first time it is called
    /// - Parameter tabViewItem: the tab view item configured with the view that shall be in the first fixed tab.
    var primaryTab: NSTabViewItem? {
        didSet {
            //remove from tabView if there was a prevous primary tab
            if let primaryTab = oldValue {
                tabView.removeTabViewItem(primaryTab)
            }
            if let primaryTab = self.primaryTab {
                tabView.insertTabViewItem(primaryTab, at: 0)
                tabBar.select(primaryTab)
            }
        }
    }

    var activeTab: Tab? {
        tabView.selectedTabViewItem?.viewController as? Tab
    }

    var browserTabCount: Int {
        tabView.numberOfTabViewItems
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

    override func viewDidLoad() {
        super.viewDidLoad()
        restoreTabs()
    }

    func createNewTab(_ url: URL? = nil, inBackground: Bool = false, load: Bool = false) -> Tab {
        let newTab = BrowserTab()

		newTab.tabUrl = url
        newTab.title = title

        if load {
            newTab.loadTab()
        }

		let newTabViewItem = TitleChangingTabViewItem(viewController: newTab)
		newTabViewItem.hasCloseButton = true
		tabView.addTabViewItem(newTabViewItem)

		if !inBackground {
			tabBar.select(newTabViewItem)
            if load {
                newTab.webView.becomeFirstResponder()
            } else {
                newTab.activateAddressBar()
            }
			//TODO: make first responder?
		}

        newTab.webView.uiDelegate = self

        //TODO: tab view order

        return newTab
    }

    func switchToPrimaryTab() {
        if self.primaryTab != nil {
            self.tabView.selectTabViewItem(at: 0)
        }
    }

	func showPreviousTab() {
        self.tabView.selectPreviousTabViewItem(nil)
    }

	func showNextTab() {
        self.tabView.selectNextTabViewItem(nil)
    }

    func restoreTabs() {
        let tabLinks = Preferences.standard().array(forKey: "TabList") as? [String]
        let tabTitles = Preferences.standard().object(forKey: "TabTitleDict") as? [String: String]

        for i in 0..<(tabLinks?.count ?? 0) {
            guard let urlString = tabLinks?[i], let url = URL(string: urlString) else {
                continue
            }
            let tab = createNewTab(url, inBackground: true, load: false) as? BrowserTab
            tab?.title = tabTitles?[urlString] ?? NSLocalizedString("New tab", comment: "")
        }
    }

	func saveOpenTabs() {

        let tabs = tabBar.tabView.tabViewItems.compactMap { $0.viewController as? BrowserTab }

        let tabLinks = tabs.compactMap { $0.tabUrl?.absoluteString }
        let tabTitles = Dictionary(tabs.filter {
            $0.tabUrl != nil && $0.title != nil
        }.map {
            ($0.tabUrl!.absoluteString, $0.title!)
        }, uniquingKeysWith: { $1 })

        Preferences.standard().setArray(tabLinks as [Any], forKey: "TabList")
        Preferences.standard().setObject(tabTitles, forKey: "TabTitleDict")

        Preferences.standard().save()
    }

    func closeActiveTab() {
        if let selectedTabViewItem = self.tabView.selectedTabViewItem {
            self.tabView.removeTabViewItem(selectedTabViewItem)
        }
    }

    func closeAllTabs() {
        self.tabView.tabViewItems.filter { $0 != primaryTab }.forEach {
            self.tabView.removeTabViewItem($0)
        }
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
        if let loaded = tab?.loadedUrl, !loaded {
            tab?.loadTab()
        }
    }
}

@available(OSX 10.10, *)
extension TabbedBrowserViewController: WKUIDelegate {
	//TODO: implement functionality for opening new tabs and alerts, and maybe peek actions
}
