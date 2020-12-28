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

class WebKitArticleTab: BrowserTab, ArticleContentView {

    var listView: ArticleViewDelegate?

    var articles: [Article] = [] {
        didSet {
            guard !articles.isEmpty else {
                self.clearHTML()
                return
            }

            let (htmlPath, accessPath) = converter.prepareArticleDisplay(self.articles)

            webView.loadFileURL(htmlPath, allowingReadAccessTo: accessPath)
            // TODO: prepare article files
            self.showAddressBar(false)
        }
    }

    override var tabUrl: URL? {
        get { super.tabUrl }
        set {
            super.tabUrl = newValue
            showAddressBar(true)
        }
    }

    let converter = WebKitArticleConverter()

    @objc
    init() {
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addressField.isEditable = false
        showAddressBar(false)
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

    func showAddressBar(_ show: Bool) {
        // TODO: hide / show address bar
    }

    override func activateAddressBar() {
        // TODO: ignored intentionally. Find more elegant solution
    }

    override func activateWebView() {
        // TODO: ignored intentionally. Find more elegant solution
    }

    // MARK: Navigation delegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // TODO: prevent navigation to links opened through klick
        // TODO: in the future, we might want to allow limited browsing in the primary tab
        decisionHandler(.allow)
        // TODO: make listView open link in browser tab
    }

}
