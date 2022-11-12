//
//  Tab.swift
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
protocol Tab {

    var tabUrl: URL? { get set }
    var title: String? { get }
    var textSelection: String { get }
    var html: String { get }
    var isLoading: Bool { get }

    // MARK: navigating

    // goes back and returns whether going back was possible
    func back() -> Bool
    // goes forward and returns whether going forward was possible
    func forward() -> Bool
    // returns whether it is possible to scroll down
    @objc
    optional func canScrollDown() -> Bool
    // returns whether it is possible to scroll up
    @objc
    optional func canScrollUp() -> Bool

    func searchFor(_ searchString: String, action: NSFindPanelAction)

    // MARK: tab life cycle

    func loadTab()
    func reloadTab()
    func stopLoadingTab()
    /// prepare tab for being closed
    func closeTab()

    // MARK: other actions

    func printPage()
    func activateAddressBar()
    func activateWebView()
}
