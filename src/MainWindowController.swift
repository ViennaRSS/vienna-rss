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

    // MARK: Initialization

    override func awakeFromNib() {
        super.awakeFromNib()

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

    // TODO: Make this private in Swift 4
    @IBOutlet fileprivate var statusLabel: NSTextField!
    @IBOutlet fileprivate var filterLabel: NSTextField!
    @IBOutlet fileprivate var filterButton: NSButton!

    var statusText: String? {
        get {
            return statusLabel.stringValue
        }
        set {
            statusLabel.stringValue = newValue ?? ""
        }
    }

    var filterAreaIsHidden = false {
        didSet {
            filterLabel.isHidden = filterAreaIsHidden
            filterButton.isHidden = filterAreaIsHidden
        }
    }

    // MARK: Actions

    @IBAction func changeFiltering(_ sender: NSMenuItem) { // TODO: This should be handled by ArticleController
        Preferences.standard().filterMode = sender.tag
        filterLabel.stringValue = sender.title
    }

    // MARK: Validation

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(changeFiltering(_:)) {
            menuItem.state = menuItem.tag == Preferences.standard().filterMode ? NSOnState : NSOffState
            return true
        } else {
            return super.validateMenuItem(menuItem)
        }
    }

    // MARK: Observation

    fileprivate func addObservers() { // Make this private in Swift 4
        OpenReader.sharedManager().addObserver(self, forKeyPath: #keyPath(OpenReader.statusMessage), options: .new, context: nil)
        RefreshManager.shared().addObserver(self, forKeyPath: #keyPath(RefreshManager.statusMessage), options: .new, context: nil)
    }

    fileprivate func removeObservers() { // Make this private in Swift 4
        OpenReader.sharedManager().removeObserver(self, forKeyPath: #keyPath(OpenReader.statusMessage))
        RefreshManager.shared().removeObserver(self, forKeyPath: #keyPath(RefreshManager.statusMessage))
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            return
        }

        if keyPath == #keyPath(RefreshManager.statusMessage) || keyPath == #keyPath(OpenReader.statusMessage) {
            if let status = change?[.newKey] as? String {
                statusLabel.stringValue = status
            }
        }
    }

}

// MARK: - Window delegate

extension MainWindowController: NSWindowDelegate {

    func windowDidBecomeMain(_ notification: Notification) {
        statusLabel.textColor = .windowFrameTextColor
        filterLabel.textColor = .windowFrameTextColor
        filterButton.isEnabled = true

        addObservers()
    }

    func windowDidResignMain(_ notification: Notification) {
        statusLabel.textColor = .disabledControlTextColor
        filterLabel.textColor = .disabledControlTextColor
        filterButton.isEnabled = false

        removeObservers()
    }

}
