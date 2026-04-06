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

    @objc weak var articleController: ArticleController!

    // MARK: Transitional outlets

    @IBOutlet private(set) var mainWindowContentViewController: NSViewController!

    @IBOutlet private(set) var splitView: NSSplitView!
    @IBOutlet private(set) var outlineView: FolderView?
    @IBOutlet private(set) var articleListView: ArticleListView?
    @IBOutlet private(set) var unifiedDisplayView: UnifiedDisplayView?

    @objc private(set) var toolbarSearchField: NSSearchField?
    @IBOutlet private(set) weak var placeholderDetailView: NSView!

    @objc private(set) lazy var browser: (any Browser & NSViewController) = {
        var controller = TabbedBrowserViewController() as (any Browser & NSViewController)
        return controller
    }()

    @IBOutlet private var subscribeToolbarItemMenu: NSMenu!
    @IBOutlet private var actionToolbarItemMenu: NSMenu!
    @IBOutlet private var filterToolbarItemMenu: NSMenu!
    @IBOutlet private var styleToolbarItemMenu: NSMenu!

    // MARK: Initialization

    override func windowDidLoad() {
        super.windowDidLoad()

        // This view controller is needed to perform storyboard segues, until
        // the window controller itself is instantiated by a storyboard.
        contentViewController = mainWindowContentViewController

        // workaround for autosave not working when name is set in Interface Builder
        // cf. https://stackoverflow.com/q/16587058
        splitView.autosaveName = "VNASplitView"

        (self.browser as? any RSSSource)?.rssSubscriber = self

        statusBarState(disclosed: Preferences.standard.showStatusBar, animate: false)

        splitView.addSubview(browser.view)
        placeholderDetailView.removeFromSuperview()

        self.articleController.articleListView = self.articleListView
        self.articleController.unifiedListView = self.unifiedDisplayView
        self.articleListView?.appController = NSApp.appController
        self.unifiedDisplayView?.appController = NSApp.appController
        self.articleListView?.articleController = self.articleController
        self.unifiedDisplayView?.articleController = self.articleController
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
        if unreadCount > 0 && UserDefaults.standard.bool(forKey: MAPref_ShowUnreadCounts) {
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

    var shareableItemsSubject = String()

    private var shareableItems: [any NSPasteboardWriting] {
        var items = [URL]()
        if let activeTab = browser.activeTab, let url = activeTab.tabUrl {
            items.append(url)
            shareableItemsSubject = activeTab.title ?? NSLocalizedString("URL", comment: "URL")
        } else {
            if let articles = articleListView?.markedArticleRange as? [Article] {
                let links = articles.compactMap { $0.link }
                let urls = links.compactMap { URL(string: $0) }
                items = urls
                if articles.count == 1 {
                    shareableItemsSubject = articles[0].title ?? ""
                } else {
                    shareableItemsSubject = String(format: NSLocalizedString("%u articles", comment: ""), articles.count)
                }
            }
        }
        return items as [NSURL]
    }

    private func toolbarItem(
        forSharingService service: NSSharingService,
        identifier: NSToolbarItem.Identifier
    ) -> NSToolbarItem {
        let item = RepresentingToolbarItem(itemIdentifier: identifier)
        item.representedObject = service
        item.action = #selector(performSharingService(_:))
        return item
    }

    @IBAction private func invokeSharingServicePicker(_ sender: Any) {
        // The sender is either the menu item in the main menu, the menu-form
        // representation of the toolbar item in label-only mode or the toolbar
        // item itself when its isBordered property is enabled.
        if sender is NSMenuItem || sender is NSToolbarItem,
            let window,
            let contentView = window.contentView
        {
            let layoutRect = window.contentLayoutRect
            // The menu or toolbar item does not have a view to which the picker
            // could be attached. The window's content view is used instead, but
            // a location is still needed.
            let xCoordinate: CGFloat
            // If the action was sent from within the window (e.g. label-only
            // mode), an approximate horizontal location can be retrieved from
            // the current NSEvent, otherwise the midpoint of the window content
            // layout rect is used.
            if let event = NSApp.currentEvent, event.window == window {
                xCoordinate = event.locationInWindow.x
            } else {
                xCoordinate = layoutRect.midX - 1
            }
            // Subtract 1 point from the Y coordinate and make the rect 1 point
            // in size, so that it fits within the coordinates of the view.
            let origin = NSPoint(x: xCoordinate, y: layoutRect.maxY - 1)
            let topEdge = NSRect(origin: origin, size: NSSize(width: 1, height: 1))
            let picker = NSSharingServicePicker(items: shareableItems)
            picker.delegate = self
            picker.show(relativeTo: topEdge, of: contentView, preferredEdge: .minY)
            return
        }

        // The sender is a button if the user clicked on the toolbar item in
        // icon-and-label mode or icon-only mode.
        if let button = sender as? NSButton {
            let picker = NSSharingServicePicker(items: shareableItems)
            picker.delegate = self
            picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
            return
        }
    }

    @IBAction private func performSharingService(_ sender: Any) {
        if (sender as? SharingServiceMenuItem)?.name == "emailLink" {
            if let sharingService = NSSharingService(named: .composeEmail) {
                sharingService.delegate = self
                sharingService.perform(withItems: shareableItems)
            }
        }

        if (sender as? SharingServiceMenuItem)?.name == "safariReadingList" {
            if let sharingService = NSSharingService(named: .addToSafariReadingList) {
                sharingService.delegate = self
                sharingService.perform(withItems: shareableItems)
            }
        }

        if let sharingService = (sender as? RepresentingToolbarItem)?.representedObject as? NSSharingService {
            sharingService.delegate = self
            sharingService.perform(withItems: shareableItems)
        }
    }

    // MARK: Responder chain

    override func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
        if self.browser.activeTab == nil && articleController.responds(to: action) {
            return articleController
        }
        return super.supplementalTarget(forAction: action, sender: sender)
    }

    override func supplementalHandler(for event: NSEvent) -> NSResponder? {
        if self.articleController.canHandle(event) {
            return self.articleController
        }
        return self
    }

    override func handle(_ event: NSEvent) -> Bool {
        return NSApp.appController.handleKeyDown(event)
    }

    // MARK: Observation

    private var observationTokens: [NSKeyValueObservation] = []

    // MARK: Window restoration

    override static var restorableStateKeyPaths: [String] {
        var keyPaths = super.restorableStateKeyPaths
        keyPaths += ["unreadCount", "currentFilter"]
        return keyPaths
    }

}

// MARK: - Menu-item validation

extension MainWindowController: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
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
            articleController.observe(\.filterModeLabel, options: .initial) { [weak self] controller, _ in
                self?.currentFilter = controller.filterModeLabel
            },
            OpenReader.shared.observe(\.statusMessage, options: [.initial, .new]) { [weak self] manager, change in
                if change.newValue is String {
                    self?.statusLabel.stringValue = manager.statusMessage
                }
            },
            RefreshManager.shared.observe(\.statusMessage, options: [.initial, .new]) { [weak self] manager, change in
                if change.newValue is String {
                    self?.statusLabel.stringValue = manager.statusMessage
                }
            },
            UserDefaults.standard.observe(\.ShowUnreadCounts) { [weak self] _, _ in
                self?.updateSubtitle()
            }
        ]
    }

}

// MARK: - Toolbar delegate

extension MainWindowController: NSToolbarDelegate {

    private var pluginManager: PluginManager? {
        return NSApp.appController.pluginManager
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == .search {
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

            item.label = NSLocalizedString(
                "search.toolbarItem.label",
                value: "Search",
                comment: "Toolbar item label")
            item.paletteLabel = NSLocalizedString(
                "search.toolbarItem.paletteLabel",
                value: "Search",
                comment: "Toolbar item palette label")
            item.toolTip = NSLocalizedString(
                "search.toolbarItem.toolTip",
                value: "Search",
                comment: "Toolbar item tooltip")

            item.action = #selector(AppController.searchUsingToolbarTextField(_:))
            item.menuFormRepresentation = NSMenuItem(title: item.label, action: item.action, keyEquivalent: "")

            toolbarSearchField?.sendsWholeSearchString = true
            toolbarSearchField?.cell?.sendsActionOnEndEditing = false

            return item
        }

        if itemIdentifier == .refresh {
            let item = ToggleButtonToolbarItem(itemIdentifier: itemIdentifier)
            item.action = #selector(AppController.refreshAllSubscriptions(_:))
            if #available(macOS 15, *) {
                item.image = NSImage(
                    systemSymbolName: "arrow.trianglehead.clockwise.rotate.90",
                    accessibilityDescription: nil
                )!
                // stopProgressTemplateName is available for macOS 10.13 too,
                // but on macOS 11+ it is backed by an SF Symbol, whereas on
                // macOS 10.13 it is a bitmap image. Due to a bug in NSButton,
                // both image and alternateImage must have the same NSImageRep,
                // otherwise the images are not aligned correctly.
                item.alternateImage = NSImage(named: NSImage.stopProgressTemplateName)
            } else {
                item.image = NSImage(resource: .syncTemplate)
                item.alternateImage = NSImage(resource: .cancelTemplate)
            }
            item.label = NSLocalizedString(
                "refresh.toolbarItem.label",
                value: "Refresh",
                comment: "Toolbar item label")
            item.paletteLabel = NSLocalizedString(
                "refresh.toolbarItem.paletteLabel",
                value: "Refresh",
                comment: "Toolbar item palette label")
            item.toolTip = NSLocalizedString(
                "Refresh all your subscriptions",
                comment: "Toolbar item tooltip")
            return item
        }

        if itemIdentifier == .share {
            let item = ButtonToolbarItem(itemIdentifier: itemIdentifier)
            item.action = #selector(invokeSharingServicePicker(_:))
            if let button = item.button {
                // The share sheet should also appear when the user presses down
                // the left mouse button, not when the user releases the button.
                // This is the behavior of the share button elsewhere in macOS.
                button.sendAction(on: .leftMouseDown)
            }
            item.image = NSImage(named: NSImage.shareTemplateName)
            item.label = NSLocalizedString(
                "share.toolbarItem.label",
                value: "Share",
                comment: "Toolbar item label")
            item.paletteLabel = NSLocalizedString(
                "share.toolbarItem.paletteLabel",
                value: "Share",
                comment: "Toolbar item palette label")
            return item
        }

        if itemIdentifier == .email {
            guard let service = NSSharingService(named: .composeEmail) else {
                return nil
            }
            let item = toolbarItem(forSharingService: service, identifier: .email)
            item.label = NSLocalizedString(
                "emailLink.toolbarItem.label",
                value: "Email Link",
                comment: "Toolbar item label")
            item.paletteLabel = NSLocalizedString(
                "emailLink.toolbarItem.paletteLabel",
                value: "Email Link",
                comment: "Toolbar item palette label")
            item.toolTip = NSLocalizedString(
                "Email a link to the current article or website",
                comment: "Toolbar item tooltip")
            if #available(macOS 11, *) {
                item.image = NSImage(systemSymbolName: "envelope", accessibilityDescription: nil)
            } else {
                item.image = NSImage(resource: .mailTemplate)
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

        if itemIdentifier == .subscribe {
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.menu = subscribeToolbarItemMenu
            item.image = NSImage(resource: .newFeedTemplate)
            item.label = NSLocalizedString(
                "subscribe.toolbarItem.label",
                value: "Add",
                comment: "Toolbar item label"
            )
            item.paletteLabel = NSLocalizedString(
                "subscribe.toolbarItem.paletteLabel",
                value: "Add",
                comment: "Toolbar item palette label"
            )
            item.toolTip = NSLocalizedString(
                "Subscribe to a feed or add a folder or smart folder.",
                comment: "Toolbar item tooltip"
            )
            return item
        }

        if itemIdentifier == .action {
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.menu = actionToolbarItemMenu
            item.image = NSImage(named: NSImage.actionTemplateName)
            item.label = NSLocalizedString(
                "action.toolbarItem.label",
                value: "Action",
                comment: "Toolbar item label"
            )
            item.paletteLabel = NSLocalizedString(
                "action.toolbarItem.paletteLabel",
                value: "Action",
                comment: "Toolbar item palette label"
            )
            item.toolTip = NSLocalizedString(
                "Additional actions for the selected folder",
                comment: "Toolbar item tooltip"
            )
            return item
        }

        if itemIdentifier == .filter {
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.menu = filterToolbarItemMenu
            item.image = NSImage(resource: .funnelFilterTemplate)
            item.label = NSLocalizedString(
                "filter.toolbarItem.label",
                value: "Filter",
                comment: "Toolbar item label"
            )
            item.paletteLabel = NSLocalizedString(
                "filter.toolbarItem.paletteLabel",
                value: "Filter",
                comment: "Toolbar item palette label"
            )
            return item
        }

        if itemIdentifier == .styles {
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.menu = styleToolbarItemMenu
            if #available(macOS 11, *) {
                item.image = NSImage(
                    systemSymbolName: "paintbrush",
                    accessibilityDescription: nil
                )
            } else {
                item.image = NSImage(resource: .styleTemplate)
            }
            item.label = NSLocalizedString(
                "style.toolbarItem.label",
                value: "Style",
                comment: "Toolbar item label"
            )
            item.paletteLabel = NSLocalizedString(
                "style.toolbarItem.paletteLabel",
                value: "Style",
                comment: "Toolbar item palette label"
            )
            item.toolTip = NSLocalizedString(
                "Display the list of available styles",
                comment: "Toolbar item tooltip"
            )
            return item
        }

        return pluginManager?.toolbarItem(forIdentifier: itemIdentifier.rawValue)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = [
            .subscribe,
            .previous,
            .next,
            .skip,
            .markAllAsRead,
            .refresh,
            .filter,
            .share,
            .email,
            .safariReadingList,
            .delete,
            .emptyTrash,
            .getInfo,
            .action,
            .styles,
            .search
        ]

        let pluginIdentifiers = pluginManager?.toolbarItems ?? []
        pluginIdentifiers.forEach { pluginIdentifier in
            identifiers.append(NSToolbarItem.Identifier(pluginIdentifier))
        }

        identifiers += [.space, .flexibleSpace]

        return identifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = [
            .subscribe,
            .skip,
            .action,
            .refresh,
            .filter,
            .share
        ]

        let pluginIdentifiers = pluginManager?.defaultToolbarItems() as? [String] ?? []
        pluginIdentifiers.forEach { identifier in
            identifiers.append(NSToolbarItem.Identifier(identifier))
        }

        identifiers += [.flexibleSpace, .search]

        return identifiers
    }

}

// MARK: - Menu delegate

extension MainWindowController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.identifier == .stylesMenu else {
            return
        }

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

    func sharingService(
        _ sharingService: NSSharingService,
        willShareItems items: [Any]
    ) {
        sharingService.subject = shareableItemsSubject
    }
}

// MARK: - NSSharingServicePickerDelegate

extension MainWindowController: NSSharingServicePickerDelegate {

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        delegateFor sharingService: NSSharingService
    ) -> (any NSSharingServiceDelegate)? {
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

// MARK: - UserDefaults

extension UserDefaults {

    // swiftlint:disable:next identifier_name
    @objc fileprivate dynamic var ShowUnreadCounts: Bool {
        return bool(forKey: MAPref_ShowUnreadCounts)
    }
}

// MARK: - Constants

private extension NSToolbarItem.Identifier {

    static let action = NSToolbarItem.Identifier("Action")
    static let delete = NSToolbarItem.Identifier("DeleteArticle")
    static let email = NSToolbarItem.Identifier("MailLink")
    static let emptyTrash = NSToolbarItem.Identifier("EmptyTrash")
    static let filter = NSToolbarItem.Identifier("Filter")
    static let getInfo = NSToolbarItem.Identifier("GetInfo")
    static let markAllAsRead = NSToolbarItem.Identifier("MarkAllItemsAsRead")
    static let next = NSToolbarItem.Identifier("NextButton")
    static let previous = NSToolbarItem.Identifier("PreviousButton")
    static let refresh = NSToolbarItem.Identifier("Refresh")
    static let safariReadingList = NSToolbarItem.Identifier("SafariReadingList")
    static let search = NSToolbarItem.Identifier("SearchItem")
    static let share = NSToolbarItem.Identifier("Share")
    static let skip = NSToolbarItem.Identifier("SkipFolder")
    static let styles = NSToolbarItem.Identifier("Styles")
    static let subscribe = NSToolbarItem.Identifier("Subscribe")

}

private extension NSUserInterfaceItemIdentifier {

    static let stylesMenu = NSUserInterfaceItemIdentifier("StylesMenu")

}
