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

    @IBOutlet var outlineView: FolderView?
    @IBOutlet var browserView: BrowserView?
    @IBOutlet var articleListView: ArticleListView?
    @IBOutlet var unifiedDisplayView: UnifiedDisplayView?
    @IBOutlet var filterDisclosureView: DisclosureView?
    @IBOutlet var filterSearchField: NSSearchField?
    @IBOutlet var toolbarSearchField: NSSearchField?

    // MARK: Initialization

    override func awakeFromNib() {
        super.awakeFromNib()

        // TODO: Move this to windowDidLoad()
        statusBarState(disclosed: Preferences.standard().showStatusBar, animate: false)

        if #available(OSX 10.10, *) {
            // Leave the default
        } else {
            statusLabel.cell?.backgroundStyle = .raised
            filterLabel.cell?.backgroundStyle = .raised
        }

        let filterMenu = (NSApp as? ViennaApp)?.filterMenu
        let filterMode = Preferences.standard().filterMode
        if let menuTitle = filterMenu?.item(withTag: filterMode)?.title {
            filterLabel.stringValue = menuTitle
        }
    }

    // MARK: Status bar

    @IBOutlet private var statusBar: DisclosureView!
    @IBOutlet private var statusLabel: NSTextField!
    @IBOutlet private var filterLabel: NSTextField!
    @IBOutlet private var filterButton: NSButton!

    @objc var statusText: String? {
        get {
            return statusLabel.stringValue
        }
        set {
            statusLabel.stringValue = newValue ?? ""
        }
    }

    @objc var filterAreaIsHidden = false {
        didSet {
            filterLabel.isHidden = filterAreaIsHidden
            filterButton.isHidden = filterAreaIsHidden
        }
    }

    private func statusBarState(disclosed: Bool, animate: Bool = true) {
        if statusBar.isDisclosed && !disclosed {
            statusBar.collapse(animate)
            Preferences.standard().showStatusBar = false

            // If the animation is interrupted, don't hide the content border.
            if !statusBar.isDisclosed {
                window?.setContentBorderThickness(0, for: .minY)
            }
        } else if !statusBar.isDisclosed && disclosed {
            let height = statusBar.disclosedView.frame.size.height
            window?.setContentBorderThickness(height, for: .minY)
            statusBar.disclose(animate)
            Preferences.standard().showStatusBar = true
        }
    }

    // MARK: Actions

    @IBAction func changeFiltering(_ sender: NSMenuItem) { // TODO: This should be handled by ArticleController
        Preferences.standard().filterMode = sender.tag
        filterLabel.stringValue = sender.title
    }

    @IBAction func toggleStatusBar(_ sender: AnyObject) {
        statusBarState(disclosed: !statusBar.isDisclosed)
    }

    // MARK: Validation

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(changeFiltering(_:)) {
            menuItem.state = menuItem.tag == Preferences.standard().filterMode ? .on     : .off
        } else if menuItem.action == #selector(toggleStatusBar(_:)) {
            if statusBar.isDisclosed {
                menuItem.title = NSLocalizedString("Hide Status Bar", comment: "Title of a menu item")
            } else {
                menuItem.title = NSLocalizedString("Show Status Bar", comment: "Title of a menu item")
            }
        } else {
            return super.validateMenuItem(menuItem)
        }

        // At this point, assume that the menu item is enabled.
        return true
    }

    // MARK: Observation

    private var observationTokens: [NSKeyValueObservation]?

}

// MARK: - Window delegate

extension MainWindowController: NSWindowDelegate {

    func windowDidBecomeMain(_ notification: Notification) {
        statusLabel.textColor = .windowFrameTextColor
        filterLabel.textColor = .windowFrameTextColor
        filterButton.isEnabled = true

        observationTokens = [
            OpenReader.sharedManager().observe(\.statusMessage, options: .new) { [weak self] manager, change in
                if change.newValue is String {
                    self?.statusLabel.stringValue = manager.statusMessage
                }
            },
            RefreshManager.shared().observe(\.statusMessage, options: .new) { [weak self] manager, change in
                if change.newValue is String {
                    self?.statusLabel.stringValue = manager.statusMessage
                }
            }
        ]
    }

    func windowDidResignMain(_ notification: Notification) {
        statusLabel.textColor = .disabledControlTextColor
        filterLabel.textColor = .disabledControlTextColor
        filterButton.isEnabled = false

        observationTokens = nil
    }

}

// MARK: - Toolbar delegate

extension MainWindowController: NSToolbarDelegate {

    private var pluginManager: PluginManager? {
        return (NSApp.delegate as? AppController)?.pluginManager
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        return pluginManager?.toolbarItem(forIdentifier: itemIdentifier.rawValue)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        typealias Identifier = NSToolbarItem.Identifier

        var identifiers = [
            Identifier("Subscribe"),
            Identifier("PreviousButton"),
            Identifier("NextButton"),
            Identifier("SkipFolder"),
            Identifier("MarkAllItemsAsRead"),
            Identifier("Refresh"),
            Identifier("MailLink"),
            Identifier("EmptyTrash"),
            Identifier("GetInfo"),
            Identifier("Action"),
            Identifier("Styles"),
            Identifier("SearchItem")
        ]

        let pluginIdentifiers = pluginManager?.toolbarItems ?? []
        pluginIdentifiers.forEach { pluginIdentifier in
            identifiers.append(Identifier(pluginIdentifier))
        }

        identifiers += [.space, .flexibleSpace]

        return identifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        typealias Identifier = NSToolbarItem.Identifier

        var identifiers = [
            Identifier("Subscribe"),
            Identifier("SkipFolder"),
            Identifier("Action"),
            Identifier("Refresh")
        ]

        let pluginIdentifiers = pluginManager?.defaultToolbarItems() as? [String] ?? []
        pluginIdentifiers.forEach { identifier in
            identifiers.append(Identifier(identifier))
        }

        identifiers += [.flexibleSpace, Identifier("SearchItem")]

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

        if let styles = (Array(ArticleView.loadStylesMap().keys) as? [String])?.sorted() {
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
