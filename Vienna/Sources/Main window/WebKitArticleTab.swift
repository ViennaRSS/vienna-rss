//
//  WebKitArticleTab.swift
//  Vienna
//
//  Copyright 2020 Tassilo Karge
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

import Foundation

class WebKitArticleTab: BrowserTab, ArticleContentView, CustomWKUIDelegate {

    var listView: ArticleViewDelegate?

    var articles: [Article] = [] {
        didSet {
            guard !articles.isEmpty else {
                self.clearHTML()
                return
            }

            let (htmlPath, accessPath) = converter.prepareArticleDisplay(self.articles)

            webView.loadFileURL(htmlPath, allowingReadAccessTo: accessPath)
        }
    }

    override var tabUrl: URL? {
        get { super.tabUrl }
        set {
            super.tabUrl = newValue
        }
    }

    let converter = WebKitArticleConverter()

    @objc
    init() {
        super.init()
        self.webView.contextMenuProvider = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addressField.isEditable = false
        hideAddressBar(true)
    }

    func clearHTML() {
        guard let blankUrl = URL(string: "about:blank") else {
            return
        }
        self.url = blankUrl
        self.loadTab()
    }

    func printDocument(_ sender: Any) {
        // TODO
    }

    func abortJavascriptAndPlugIns() {
        // TODO
    }

    func useUserPrefsForJavascriptAndPlugIns() {
        // TODO
    }

    func forceJavascript() {
        // TODO
    }

    func scrollToTop() {
        // TODO
    }

    func scrollToBottom() {
        // TODO
    }

    func makeTextSmaller(_ sender: Any) {
        // TODO
    }

    func makeTextLarger(_ sender: Any) {
        // TODO
    }

    // MARK: gui

    override func activateAddressBar() {
        // TODO: ignored intentionally. Find more elegant solution
    }

    override func activateWebView() {
        // TODO: ignored intentionally. Find more elegant solution
    }

    // MARK: Navigation delegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // TODO: how do forms work in the article view?
        // i.e. navigationAction.navigationType == .formSubmitted or .formResubmitted
        // TODO: in the future, we might want to allow limited browsing in the primary tab
        if navigationAction.navigationType == .linkActivated {
            // prevent navigation to links opened through klick
            decisionHandler(.cancel)
            // open in new preferred browser instead, or the alternate one if the option key is pressed
            let openInPreferredBrower = !navigationAction.modifierFlags.contains(.option)
            // TODO: maybe we need to add an api that opens a clicked link in foreground to the AppController
            NSApp.appController.open(navigationAction.request.url, inPreferredBrowser: openInPreferredBrower)
        } else {
            decisionHandler(.allow)
        }
    }

    // MARK: CustomWKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let browser = NSApp.appController.browser
        if let webKitBrowser = browser as? TabbedBrowserViewController {
            let newTab = webKitBrowser.createNewTab(navigationAction.request, config: configuration, inBackground: false)
            return (newTab as? BrowserTab)?.webView
        } else {
            // Fallback for old browser
            _ = browser?.createNewTab(navigationAction.request.url, inBackground: false, load: false)
            return nil
        }
    }

    func contextMenuItemsFor(purpose: WKWebViewContextMenuContext, existingMenuItems: [NSMenuItem]) -> [NSMenuItem] {
        var menuItems = existingMenuItems
        switch purpose {
        case .page(url: _):
            break
        case .link(let url):
            addLinkMenuCustomizations(&menuItems, url)
        case .picture:
            break
        case .pictureLink(image: _, link: let link):
            addLinkMenuCustomizations(&menuItems, link)
        case .text:
            break
        }
        return WebKitContextMenuCustomizer.contextMenuItemsFor(purpose: purpose, existingMenuItems: menuItems)
    }

    private func addLinkMenuCustomizations(_ menuItems: inout [NSMenuItem], _ url: (URL)) {

        if let index = menuItems.firstIndex(where: { $0.identifier == .WKMenuItemOpenLink }) {
            menuItems.remove(at: index)
        }

        if let index = menuItems.firstIndex(where: { $0.identifier == .WKMenuItemOpenLinkInNewWindow }) {

            menuItems[index].title = NSLocalizedString("Open Link in New Tab", comment: "")

            let openInBackgroundTitle = NSLocalizedString("Open Link in Background", comment: "")
            let openInBackgroundItem = NSMenuItem(title: openInBackgroundTitle, action: #selector(openLinkInBackground(menuItem:)), keyEquivalent: "")
            openInBackgroundItem.identifier = .WKMenuItemOpenLinkInBackground
            openInBackgroundItem.representedObject = url
            menuItems.insert(openInBackgroundItem, at: menuItems.index(after: index))
        }
    }

    @objc
    func openLinkInBackground(menuItem: NSMenuItem) {
        if let url = menuItem.representedObject as? URL {
            _ = NSApp.appController.browser.createNewTab(url, inBackground: true, load: true)
        }
    }
}
