//
//  MainWindowViewController.swift
//  Vienna
//
//  Copyright 2025 Eitot
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
final class MainWindowViewController: NSViewController {

    @IBOutlet private var splitView: NSSplitView!
    @IBOutlet private(set) var outlineView: FolderView!
    private(set) var browser: (any Browser & NSViewController)!
    private(set) var articleController = ArticleController()
    @IBOutlet private(set) var articleListView: ArticleListView!
    @IBOutlet private(set) var unifiedDisplayView: UnifiedDisplayView!
    @IBOutlet private(set) var statusBar: DisclosureView!
    @IBOutlet private(set) var statusLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        // workaround for autosave not working when name is set in Interface Builder
        // cf. https://stackoverflow.com/q/16587058
        splitView.autosaveName = "VNASplitView"

        articleController.articleListView = articleListView
        articleController.unifiedListView = unifiedDisplayView
        articleListView.appController = NSApp.appController
        unifiedDisplayView.appController = NSApp.appController
        articleListView.articleController = articleController
        unifiedDisplayView.articleController = articleController

        // awakeFromNib() is unreliable, because it may be called twice during
        // Storyboard instantiation. Until these classes are embedded in their
        // own view controllers, we have to initiate post-init setup here.
        articleListView.initialiseArticleView()
        unifiedDisplayView.initTableView()
    }

    // MARK: NSSeguePerforming

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let browser = segue.destinationController as? TabbedBrowserViewController {
            self.browser = browser
            return
        }
    }

}
