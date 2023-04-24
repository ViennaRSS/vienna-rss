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
                self.loadHTMLString("<html><meta name=\"color-scheme\" content=\"light dark\"><body></body></html>", baseURL: URL.blank)
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

    func contextMenuItemsFor(purpose: WKWebViewContextMenuContext, existingMenuItems: [NSMenuItem]) -> [NSMenuItem] {
        var menuItems = existingMenuItems
        switch purpose {
        case .link(let url):
            addLinkMenuCustomizations(&menuItems, url)
        case .mediaLink(media: _, link: let link):
            addLinkMenuCustomizations(&menuItems, link)
        default:
            break
        }
        return contextMenuCustomizer.contextMenuItemsFor(purpose: purpose, existingMenuItems: menuItems)
    }

    private func addLinkMenuCustomizations(_ menuItems: inout [NSMenuItem], _ url: (URL)) {

        if let index = menuItems.firstIndex(where: { $0.identifier == .WKMenuItemOpenLink }) {
            menuItems.remove(at: index)
        }

    }

    @objc
    func processMenuItem(_ menuItem: NSMenuItem) {
        guard let url = menuItem.representedObject as? URL else {
            return
        }
        switch menuItem.identifier {
        case NSUserInterfaceItemIdentifier.WKMenuItemOpenLinkInBackground:
            _ = NSApp.appController.browser.createNewTab(url, inBackground: true, load: true)
        case NSUserInterfaceItemIdentifier.WKMenuItemOpenLinkInNewWindow, NSUserInterfaceItemIdentifier.WKMenuItemOpenImageInNewWindow, NSUserInterfaceItemIdentifier.WKMenuItemOpenMediaInNewWindow:
            _ = NSApp.appController.browser.createNewTab(url, inBackground: false, load: true)
        case NSUserInterfaceItemIdentifier.WKMenuItemOpenLinkInSystemBrowser:
            NSApp.appController.openURL(inDefaultBrowser: url)
        case NSUserInterfaceItemIdentifier.WKMenuItemDownloadImage, NSUserInterfaceItemIdentifier.WKMenuItemDownloadMedia, NSUserInterfaceItemIdentifier.WKMenuItemDownloadLinkedFile:
            DownloadManager.shared.downloadFile(fromURL: url.absoluteString)
        default:
            break
        }
    }

    deinit {
        deleteHtmlFile()
    }
}
