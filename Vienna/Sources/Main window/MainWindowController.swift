//
//  MainWindowController.swift
//  Vienna
//
//  Copyright 2017
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

final class MainWindowController: NSWindowController {

    // MARK: Transitional outlets

    @IBOutlet private(set) var splitView: NSSplitView!
    @IBOutlet private(set) var outlineView: FolderView?
    @IBOutlet private(set) var articleListView: ArticleListView?
    @IBOutlet private(set) var unifiedDisplayView: UnifiedDisplayView?
    @IBOutlet private(set) var filterDisclosureView: DisclosureView?
    @IBOutlet private(set) var filterDisclosureView2: DisclosureView?
    @IBOutlet private(set) var filterSearchField: NSSearchField?
    @IBOutlet private(set) var filterSearchField2: NSSearchField?

    @objc private(set) var toolbarSearchField: NSSearchField?
    @IBOutlet private(set) weak var placeholderDetailView: NSView!

    @objc private(set) lazy var browser: (Browser & NSViewController) = {
        var controller = Preferences.standard.useNewBrowser
            ? TabbedBrowserViewController() as (Browser & NSViewController)
            : WebViewBrowser()
        return controller
    }()

    // MARK: Initialization

    override func windowDidLoad() {
        super.windowDidLoad()
        // workaround for autosave not working when name is set in Interface Builder
        // cf. https://stackoverflow.com/q/16587058
        splitView.autosaveName = "VNASplitView"

        (self.browser as? RSSSource)?.rssSubscriber = self

        statusBarState(disclosed: Preferences.standard.showStatusBar, animate: false)

        splitView.addSubview(browser.view)
        placeholderDetailView.removeFromSuperview()
    }

    // MARK: Subtitle

    @objc dynamic var unreadCount: UInt = 0 {
        didSet {
            updateSubtitle()
        }
    }

    @objc dynamic var currentFilter: String = "" {
        didSet {
            updateSubtitle()
        }
    }

    private func updateSubtitle() {
        // Unread counter
        var countString = String()
        if unreadCount > 0 {
            let number = NSNumber(value: unreadCount)
            let formattedNumber = NumberFormatter.localizedString(from: number, number: .decimal)
            countString = String(format: NSLocalizedString("%@ unread", comment: ""), formattedNumber)
        }

        // Filter label
        var filterString = String()
        var filterStringCapitalized = String()
        if !currentFilter.isEmpty {
            filterString = String(format: NSLocalizedString("filter by: %@", comment: ""), currentFilter)
            filterStringCapitalized = String(format: NSLocalizedString("Filter by: %@", comment: ""), currentFilter)
        }

        // Combine the strings
        if !countString.isEmpty && !filterString.isEmpty {
            if #available(macOS 11, *) {
                window?.subtitle = "\(countString) – \(filterString)"
            } else {
                let appName = NSRunningApplication.current.localizedName!
                window?.title = "\(appName) (\(countString), \(filterString))"
            }
        } else if !countString.isEmpty && filterString.isEmpty {
            if #available(macOS 11, *) {
                window?.subtitle = countString
            } else {
                let appName = NSRunningApplication.current.localizedName!
                window?.title = "\(appName) (\(countString))"
            }
        } else if countString.isEmpty && !filterString.isEmpty {
            if #available(macOS 11, *) {
                window?.subtitle = filterStringCapitalized
            } else {
                let appName = NSRunningApplication.current.localizedName!
                window?.title = "\(appName) (\(filterString))"
            }
        } else {
            if #available(macOS 11, *) {
                window?.subtitle = ""
            } else {
                window?.title = NSRunningApplication.current.localizedName!
            }
        }

    }

    // MARK: Status bar

    @IBOutlet private var statusBar: DisclosureView!
    @IBOutlet private var statusLabel: NSTextField!

    @objc var statusText: String? {
        get {
            return statusLabel.stringValue
        }
        set {
            statusLabel.stringValue = newValue ?? ""
        }
    }

    private func statusBarState(disclosed: Bool, animate: Bool = true) {
        if statusBar.isDisclosed && !disclosed {
            statusBar.collapse(animate)
            Preferences.standard.showStatusBar = false

            // If the animation is interrupted, don't hide the content border.
            if !statusBar.isDisclosed {
                window?.setContentBorderThickness(0, for: .minY)
            }
        } else if !statusBar.isDisclosed && disclosed {
            let height = statusBar.disclosedView.frame.size.height
            window?.setContentBorderThickness(height, for: .minY)
            statusBar.disclose(animate)
            Preferences.standard.showStatusBar = true
        }
    }

    // MARK: Actions

    @IBAction private func changeFiltering(_ sender: NSMenuItem) { // TODO: This should be handled by ArticleController
        Preferences.standard.filterMode = sender.tag
        if sender.tag == Filter.all.rawValue {
            currentFilter = ""
        } else {
            currentFilter = sender.title
        }
    }

    @IBAction private func toggleStatusBar(_ sender: AnyObject) {
        statusBarState(disclosed: !statusBar.isDisclosed)
    }

    // MARK: Sharing services

    private var hasShareableItems: Bool {
        if let activeTab = self.browser.activeTab {
            return activeTab.tabUrl != nil
        } else {
            return self.articleListView?.selectedArticle != nil
        }
    }

    private var shareableItems: [NSPasteboardWriting] {
        var items = [URL]()
        if let activeTab = browser.activeTab, let url = activeTab.tabUrl {
            items.append(url)
        } else {
            if let articles = articleListView?.markedArticleRange as? [Article] {
                let links = articles.compactMap { $0.link }
                let urls = links.compactMap { URL(string: $0) }
                items = urls
            }
        }
        return items as [NSURL]
    }

    private func toolbarItem(
        forSharingService service: NSSharingService,
        identifier: NSToolbarItem.Identifier
    ) -> NSToolbarItem {
        let item = SharingServiceToolbarItem(itemIdentifier: identifier, sharingService: service)
        if #available(macOS 10.15, *) {
            item.isBordered = true
        }
        item.action = #selector(performSharingService(_:))
        return item
    }

    @IBAction private func invokeSharingServicePicker(_ sender: Any) {
        // The sender is either the menu item in the main menu or the menu-item
        // representation of the toolbar item in text-only mode.
        if sender is NSMenuItem, let window, let contentView = window.contentView {
            let picker = NSSharingServicePicker(items: shareableItems)
            picker.delegate = self
            // The menu item does not have a view to which the picker could be
            // attached. The window's content view is used instead. The picker
            // should attach to the top middle point of the content view.
            let layoutRect = window.contentLayoutRect
            // Subtract 1 point from the coordinates and make the rect 1 point in
            // size, so that it fits within the coordinates of the view.
            let xCoordinate = layoutRect.midX - 1
            let yCoordinate = layoutRect.maxY - 1
            let topEdgeRect = NSRect(x: xCoordinate, y: yCoordinate, width: 1, height: 1)
            picker.show(relativeTo: topEdgeRect, of: contentView, preferredEdge: .minY)
        }

        // The sender is a button if the user clicked on the toolbar item.
        if let button = sender as? NSButton {
            let picker = NSSharingServicePicker(items: shareableItems)
            picker.delegate = self
            picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
        }
    }

    @IBAction private func performSharingService(_ sender: Any) {
        if (sender as? SharingServiceMenuItem)?.name == "safariReadingList" {
            let sharingService = NSSharingService(named: .addToSafariReadingList)
            sharingService?.perform(withItems: shareableItems)
        }

        if let sharingService = (sender as? SharingServiceToolbarItem)?.service {
            sharingService.perform(withItems: shareableItems)
        }
    }

    // MARK: Observation

    private var observationTokens: [NSKeyValueObservation] = []

    // MARK: Window restoration

    override class var restorableStateKeyPaths: [String] {
        var keyPaths = super.restorableStateKeyPaths
        keyPaths += ["unreadCount", "currentFilter"]
        return keyPaths
    }

}

// MARK: - Menu-item validation

extension MainWindowController: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(changeFiltering(_:)):
            menuItem.state = menuItem.tag == Preferences.standard.filterMode ? .on : .off
            return browser.activeTab == nil
        case #selector(performSharingService(_:)), #selector(invokeSharingServicePicker(_:)):
            return hasShareableItems
        case #selector(toggleStatusBar(_:)):
            if statusBar.isDisclosed {
                menuItem.title = NSLocalizedString("Hide Status Bar", comment: "Title of a menu item")
            } else {
                menuItem.title = NSLocalizedString("Show Status Bar", comment: "Title of a menu item")
            }
            return true
        default:
            return responds(to: menuItem.action)
        }
    }

}

extension MainWindowController: NSToolbarItemValidation {

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.action {
        case #selector(invokeSharingServicePicker(_:)), #selector(performSharingService(_:)):
            return hasShareableItems
        default:
            return responds(to: item.action)
        }
    }

}

// MARK: - Window delegate

extension MainWindowController: NSWindowDelegate {

    func windowDidBecomeMain(_ notification: Notification) {
        statusLabel.textColor = .windowFrameTextColor
    }

    func windowDidResignMain(_ notification: Notification) {
        statusLabel.textColor = .disabledControlTextColor
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window, window.occlusionState.contains(.visible) else {
            observationTokens.removeAll()
            return
        }

        observationTokens = [
            OpenReader.shared.observe(\.statusMessage, options: [.initial, .new]) { [weak self] manager, change in
                if change.newValue is String {
                    self?.statusLabel.stringValue = manager.statusMessage
                }
            },
            RefreshManager.shared.observe(\.statusMessage, options: [.initial, .new]) { [weak self] manager, change in
                if change.newValue is String {
                    self?.statusLabel.stringValue = manager.statusMessage
                }
            }
        ]
    }

}

// MARK: - Toolbar delegate

extension MainWindowController: NSToolbarDelegate {

    private var pluginManager: PluginManager? {
        return NSApp.appController.pluginManager
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == NSToolbarItem.Identifier("SearchItem") {
            let item: NSToolbarItem
            if #available(macOS 11, *) {
                item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
                toolbarSearchField = (item as? NSSearchToolbarItem)?.searchField
            } else {
                item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.view = NSSearchField()
                item.maxSize.width = 210
                item.visibilityPriority = .high
                toolbarSearchField = item.view as? NSSearchField
            }

            item.label = NSLocalizedString("Search Articles", comment: "Toolbar item label")
            item.paletteLabel = NSLocalizedString("Search Articles", comment: "Toolbar item palette label")
            item.toolTip = NSLocalizedString("Search Articles", comment: "Toolbar item tooltip")

            item.action = #selector(AppController.searchUsingToolbarTextField(_:))
            item.menuFormRepresentation = NSMenuItem(title: item.label, action: item.action, keyEquivalent: "")

            toolbarSearchField?.sendsWholeSearchString = true
            toolbarSearchField?.cell?.sendsActionOnEndEditing = false

            return item
        }

        if itemIdentifier == .email {
            guard let service = NSSharingService(named: .composeEmail) else {
                return nil
            }
            let item = toolbarItem(forSharingService: service, identifier: .email)
            item.label = NSLocalizedString("Email Link", comment: "Toolbar item label")
            item.paletteLabel = NSLocalizedString("Email Link", comment: "Toolbar item palette label")
            item.toolTip = NSLocalizedString(
                "Email a link to the current article or website",
                comment: "Toolbar item tooltip")
            if #available(macOS 11, *) {
                item.image = NSImage(systemSymbolName: "envelope", accessibilityDescription: nil)
            } else {
                item.image = NSImage(named: "MailTemplate")
            }
            return item
        }

        if itemIdentifier == .safariReadingList {
            guard let service = NSSharingService(named: .addToSafariReadingList) else {
                return nil
            }
            let item = toolbarItem(forSharingService: service, identifier: .safariReadingList)
            item.label = NSLocalizedString("Safari Reading List", comment: "Toolbar item label")
            item.paletteLabel = NSLocalizedString("Add to Safari Reading List", comment: "Toolbar item palette label")
            if #available(macOS 11, *) {
                item.image = NSImage(systemSymbolName: "eyeglasses", accessibilityDescription: nil)
            } else {
                item.image = service.image
            }
            return item
        }

        return pluginManager?.toolbarItem(forIdentifier: itemIdentifier.rawValue)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers = [
            NSToolbarItem.Identifier("Subscribe"),
            NSToolbarItem.Identifier("PreviousButton"),
            NSToolbarItem.Identifier("NextButton"),
            NSToolbarItem.Identifier("SkipFolder"),
            NSToolbarItem.Identifier("MarkAllItemsAsRead"),
            NSToolbarItem.Identifier("Refresh"),
            NSToolbarItem.Identifier("Filter"),
            NSToolbarItem.Identifier("Share"),
            NSToolbarItem.Identifier("MailLink"),
            NSToolbarItem.Identifier("SafariReadingList"),
            NSToolbarItem.Identifier("DeleteArticle"),
            NSToolbarItem.Identifier("EmptyTrash"),
            NSToolbarItem.Identifier("GetInfo"),
            NSToolbarItem.Identifier("Action"),
            NSToolbarItem.Identifier("Styles"),
            NSToolbarItem.Identifier("SearchItem")
        ]

        let pluginIdentifiers = pluginManager?.toolbarItems ?? []
        pluginIdentifiers.forEach { pluginIdentifier in
            identifiers.append(NSToolbarItem.Identifier(pluginIdentifier))
        }

        identifiers += [.space, .flexibleSpace]

        return identifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers = [
            NSToolbarItem.Identifier("Subscribe"),
            NSToolbarItem.Identifier("SkipFolder"),
            NSToolbarItem.Identifier("Action"),
            NSToolbarItem.Identifier("Refresh"),
            NSToolbarItem.Identifier("Filter"),
            NSToolbarItem.Identifier("Share")
        ]

        let pluginIdentifiers = pluginManager?.defaultToolbarItems() as? [String] ?? []
        pluginIdentifiers.forEach { identifier in
            identifiers.append(NSToolbarItem.Identifier(identifier))
        }

        identifiers += [.flexibleSpace, NSToolbarItem.Identifier("SearchItem")]

        return identifiers
    }

}

// MARK: - Menu delegate

extension MainWindowController: NSMenuDelegate {

    // This method is presently only called for the style menu.
    func menuNeedsUpdate(_ menu: NSMenu) {
        for menuItem in menu.items where menuItem.action == #selector(AppController.doSelectStyle(_:)) {
            menu.removeItem(menuItem)
        }

        if let styles = (Array(ArticleStyleLoader.reloadStylesMap().allKeys) as? [String])?.sorted() {
            var index = 0
            while index < styles.count {
                menu.insertItem(withTitle: styles[index],
                                action: #selector(AppController.doSelectStyle(_:)),
                                keyEquivalent: "",
                                at: index + 1)
                index += 1
            }
        }
    }

}

// MARK: - NSSharingServiceDelegate

extension MainWindowController: NSSharingServiceDelegate {

    func sharingService(
        _ sharingService: NSSharingService,
        sourceWindowForShareItems items: [Any],
        sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>
    ) -> NSWindow? {
        return window
    }

}

// MARK: - NSSharingServicePickerDelegate

extension MainWindowController: NSSharingServicePickerDelegate {

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        delegateFor sharingService: NSSharingService
    ) -> NSSharingServiceDelegate? {
        return self
    }

}

// MARK: - Rss subscriber

extension MainWindowController: RSSSubscriber {

    func isInterestedIn(_ url: URL) -> Bool {
        // TODO: check whether we already subscribed to feed
        return true
    }

    func subscribeToRSS(_ urls: [URL]) {
        // TODO : if there are multiple feeds, we should put up an UI inviting the user to pick one, as also mentioned in SubscriptionModel.m verifiedFeedURLFromURL method
        // TODO : allow user to select a folder instead of assuming current location (see #1163)
        NSApp.appController.createSubscriptionInCurrentLocation(for: urls[0])
    }
}
