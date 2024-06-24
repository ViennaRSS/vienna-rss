//
//  Browser.swift
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

@objc
protocol Browser {
    // TODO: I would love to use an associatedtype for tab here, but @objc does not allow this

    var browserTabCount: Int { get }

    // MARK: tab management

    /// The tab view item configured with the view that shall be in the first
    /// fixed tab.The browser can have a fixed first tab (e.g. bookmarks). The
    /// tab has to be managed by the setter. It will not be saved, nor be
    /// returned by the activeTab property.
    var primaryTab: NSTabViewItem? { get set }

    /// A tabbed browser always has one tab that is selected. It is called the active tab.
    /// In case the primary tab is selected, the return value is nil
    /// (because it does not necessarily implement the Tab protocol)
    var activeTab: (any Tab)? { get }

    /// Add a new tab to the open tabs of the browser
    ///
    /// - Parameters:
    ///   - url: optional URL for the new tab
    ///   - inBackground: if the tab shall stay unselected
    ///   - load: whether the page to which the URL points is supposed to be loaded immediately
    ///           (otherwise it is opened when opening the tab)
    /// - Returns: the new tab
    func createNewTab(_ url: URL?, inBackground: Bool, load: Bool) -> any Tab

    /// Saves all tabs persistently.
    /// Next time when instanciating the browser, these tabs will be re-instanciated as well.
    func saveOpenTabs()

    /// close active tab
    func closeActiveTab()

    /// Closes all open tabs (despite of the primary tab).
    /// This will not erase the saved open tabs, so next time,
    /// the saved tabs will be opened again unless the tabs
    /// are saved another time after closing!
    func closeAllTabs()

    // MARK: tab navigation

    /// if there is a primary tab set, the browser will select it and make it the active tab
    func switchToPrimaryTab()

    /// tabs are ordered (also reflected visually).
    /// Calling this method will select and activate the tab before the currently active tab.
    func showPreviousTab()

    /// tabs are ordered (also reflected visually).
    /// Calling this method will select and activate the tab after the currently active tab.
    func showNextTab()
}
