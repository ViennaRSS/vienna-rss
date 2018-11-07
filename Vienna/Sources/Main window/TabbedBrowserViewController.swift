//
//  TabbedBrowserViewController.swift
//  Vienna
//
//  Created by Tassilo Karge on 27.10.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

import Cocoa
import MMTabBarView

@available(OSX 10.10, *)
class TabbedBrowserViewController: NSViewController, Browser, MMTabBarViewDelegate {

    @IBOutlet weak var tabBar: MMTabBarView!
    @IBOutlet weak var tabView: NSTabView!

    /// The browser can have a fixed first tab (e.g. bookmarks).
    /// This method will set the primary tab the first time it is called
    /// - Parameter tabViewItem: the tab view item configured with the view that shall be in the first fixed tab.
    var primaryTab : NSTabViewItem? {
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

    var activeTab : Tab? {
        get {
            return tabView.selectedTabViewItem?.viewController as? Tab
        }
    }

    var browserTabCount: Int {
        get {
            return tabView.numberOfTabViewItems
        }
    }

    required init?(coder: NSCoder) {
        guard
            let tabBar = coder.decodeObject(of: MMTabBarView.self, forKey: "tabBar"),
            let tabView = coder.decodeObject(of: NSTabView.self, forKey: "tabView"),
            let primaryTab = coder.decodeObject(of: NSTabViewItem.self, forKey: "primaryTab")
            else {return nil}
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
        // Do view setup here.
    }

    public func createNewTab(_ url:NSURL? = nil, inBackground: Bool = false, load: Bool = false) -> Tab {
        let newTab = BrowserTab()
        let newTabViewItem = NSTabViewItem(viewController: newTab)
        tabView.addTabViewItem(newTabViewItem)

        if (url != nil) {
            //TODO: set url to tab
        }

        if load {
            //TODO: load new tab
        }

        if !inBackground {
            tabBar.select(newTabViewItem)
            //TODO: make first responder?
        }

        //TODO: tab view order

        return newTab
    }

    public func switchToPrimaryTab() {
        if self.primaryTab != nil {
            self.tabView.selectTabViewItem(at: 0)
        }
    }

    public func showPreviousTab() {
        self.tabView.selectPreviousTabViewItem(nil)
    }

    public func showNextTab() {
        self.tabView.selectNextTabViewItem(nil)
    }

    public func saveOpenTabs() {
        //TODO: implement saving mechanism
    }

    func closeAllTabs() {
        //TODO: implement
    }

    func closeActiveTab() {
        //TODO: implement
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
