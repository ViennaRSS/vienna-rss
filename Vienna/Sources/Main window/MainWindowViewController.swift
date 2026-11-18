//
//  MainWindowViewController.swift
//  Vienna
//
//  Copyright 2025-2026 Eitot
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

@objc(VNAMainWindowViewController)
final class MainWindowViewController: NSSplitViewController {

    // These were eyeballed from Apple's apps.
    private static let sidebarMinimumThickness = 190.0
    private static let sidebarMaximumThickness = 500.0

    @IBOutlet private var sidebar: NSSplitViewItem!
    @IBOutlet private var content: NSSplitViewItem!
    private(set) var foldersTree: FoldersTree?
    private(set) var browser: (any Browser & NSViewController)?
    private(set) var articleController = ArticleController()
    @IBOutlet private(set) var articleListView: ArticleListView!
    @IBOutlet private(set) var unifiedDisplayView: UnifiedDisplayView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // workaround for autosave not working when name is set in Interface Builder
        // cf. https://stackoverflow.com/q/16587058
        splitView.autosaveName = "VNASplitView"

        foldersTree = sidebar.viewController as? FoldersTree
        browser = content.viewController as? (any Browser & NSViewController)

        articleController.articleListView = articleListView
        articleController.unifiedListView = unifiedDisplayView
        articleListView.appController = NSApp.appController
        unifiedDisplayView.appController = NSApp.appController
        articleListView.articleController = articleController
        unifiedDisplayView.articleController = articleController

        // The default minimum thickness is too narrow for the status bar. The
        // split-view item does not have a maximum thickness by default.
        sidebar.minimumThickness = Self.sidebarMinimumThickness
        sidebar.maximumThickness = Self.sidebarMaximumThickness

        // TODO: Consider adding sidebar collapsing support
        // Interface Builder resets the value to true, requiring this override.
        sidebar.canCollapse = false

        // awakeFromNib() is unreliable, because it may be called twice during
        // Storyboard instantiation. Until these classes are embedded in their
        // own view controllers, we have to initiate post-init setup here.
        articleListView.initialiseArticleView()
        unifiedDisplayView.initTableView()
    }
}
