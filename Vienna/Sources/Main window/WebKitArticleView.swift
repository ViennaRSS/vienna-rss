//
//  WebKitArticleView.swift
//  Vienna
//
//  Copyright 2021 Barijaona Ramaholimihaso
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
import WebKit

class WebKitArticleView: CustomWKWebView, ArticleContentView, WKNavigationDelegate, CustomWKUIDelegate {

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

            self.loadFileURL(htmlPath, allowingReadAccessTo: htmlPath.deletingLastPathComponent())
        }
    }

    var htmlPath: URL?

    let converter = WebKitArticleConverter()

    let contextMenuCustomizer: BrowserContextMenuDelegate = WebKitContextMenuCustomizer()

    @objc
    init(frame: NSRect) {
        super.init(frame: frame, configuration: WKWebViewConfiguration())
        if responds(to: #selector(setter: _textZoomFactor)) {
            _textZoomFactor = Preferences.standard.textSizeMultiplier
        }
        contextMenuProvider = self
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

    func clearHTML() {
        deleteHtmlFile()
        load(URLRequest(url: URL.blank))
     }

    func resetTextSize() {
        makeTextStandardSize(self)
    }

    func decreaseTextSize() {
        makeTextSmaller(self)
    }

    func increaseTextSize() {
        makeTextLarger(self)
    }

    override func makeTextStandardSize(_ sender: Any?) {
        super.makeTextStandardSize(sender)
        if responds(to: #selector(getter: _textZoomFactor)) {
            Preferences.standard.textSizeMultiplier = _textZoomFactor
        }
    }

    override func makeTextLarger(_ sender: Any?) {
        super.makeTextLarger(sender)
        if responds(to: #selector(getter: _textZoomFactor)) {
            Preferences.standard.textSizeMultiplier = _textZoomFactor
        }
    }

    override func makeTextSmaller(_ sender: Any?) {
        super.makeTextSmaller(sender)
        if responds(to: #selector(getter: _textZoomFactor)) {
            Preferences.standard.textSizeMultiplier = _textZoomFactor
        }
    }

    // MARK: CustomWKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let browser = NSApp.appController.browser
        if let webKitBrowser = browser as? TabbedBrowserViewController {
            let newTab = webKitBrowser.createNewTab(navigationAction.request, config: configuration, inBackground: false)
            if let webView = webView as? CustomWKWebView {
                // The listeners are removed from the old webview userContentController on creating the new one, restore them
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
        return contextMenuCustomizer.contextMenuItemsFor(purpose: purpose, existingMenuItems: menuItems)
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

    @objc
    func openLinkInDefaultBrowser(menuItem: NSMenuItem) {
        if let url = menuItem.representedObject as? URL {
            NSApp.appController.openURL(inDefaultBrowser: url)
        }
    }

    @objc
    func contextMenuItemAction(menuItem: NSMenuItem) {
        contextMenuCustomizer.contextMenuItemAction(menuItem: menuItem)
    }

    deinit {
        deleteHtmlFile()
    }
}
