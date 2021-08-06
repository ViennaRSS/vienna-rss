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

            deleteHtmlFile()
            let htmlPath = converter.prepareArticleDisplay(self.articles)
            self.htmlPath = htmlPath

            webView.loadFileURL(htmlPath, allowingReadAccessTo: htmlPath.deletingLastPathComponent())
        }
    }

    var htmlPath: URL?

    override var tabUrl: URL? {
        get { super.tabUrl }
        set { super.tabUrl = newValue }
    }

    override var loadingProgress: Double {
        didSet {
            updateLoadingProgress(oldValue)
        }
    }

    let converter = WebKitArticleConverter()

    @objc
    init() {
        super.init()
        self.webView.contextMenuProvider = self
        self.registerNavigationEndHandler { [weak self] _ in self?.deleteHtmlFile() }
    }

    @objc
    func deleteHtmlFile() {
        guard let htmlPath = htmlPath else {
            return
        }
        do {
            try FileManager.default.removeItem(at: htmlPath)
        } catch {
        }
    }

    /// handle special keys when the article view has the focus
    override func keyDown(with event: NSEvent) {
        if let pressedKeys = event.characters, pressedKeys.count == 1 {
            let pressedKey = (pressedKeys as NSString).character(at: 0)
            // give app controller preference when handling commands
            if NSApp.appController.handleKeyDown(pressedKey, withFlags: event.modifierFlags.rawValue) {
                return
            }
        }
        super.keyDown(with: event)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addressField.isEditable = false
        hideAddressBar(true)
    }

    func clearHTML() {
        deleteHtmlFile()
        self.url = URL.blank
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

    func updateLoadingProgress(_ oldProgress: Double) {
        guard let animationLayer = self.view.layer else {
            return
        }

        let toValue = max(0.75, Float(loadingProgress))
        let fromValue = max(0.50, animationLayer.presentation()?.opacity ?? animationLayer.opacity)

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = fromValue < toValue ? 0.3 : 0.05
        animationLayer.add(animation, forKey: "opacityAnimation")

        animationLayer.opacity = toValue
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
            if let webView = webView as? CustomWKWebView {
                //the listeners are removed from the old webview userContentController on creating the new one, restore them
                webView.resetScriptListeners()
            }
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

            let defaultBrowser = getDefaultBrowser() ?? NSLocalizedString("External Browser", comment: "")
            let openInExternalBrowserTitle = NSLocalizedString("Open Link in %@", comment: "")
                .replacingOccurrences(of: "%@", with: defaultBrowser)
            let openInDefaultBrowserItem = NSMenuItem(
                title: openInExternalBrowserTitle,
                action: #selector(openLinkInDefaultBrowser(menuItem:)), keyEquivalent: "")
            openInDefaultBrowserItem.identifier = .WKMenuItemOpenLinkInSystemBrowser
            openInDefaultBrowserItem.representedObject = url
            menuItems.insert(openInDefaultBrowserItem, at: menuItems.index(after: index + 1))
        }
    }

    @objc
    func openLinkInBackground(menuItem: NSMenuItem) {
        if let url = menuItem.representedObject as? URL {
            _ = NSApp.appController.browser.createNewTab(url, inBackground: true, load: true)
        }
    }

    @objc
    func openLinkInDefaultBrowser(menuItem: NSMenuItem) {
        if let url = menuItem.representedObject as? URL {
            NSApp.appController.openURL(inDefaultBrowser: url)
        }
    }

    deinit {
        deleteHtmlFile()
    }
}
