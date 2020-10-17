//
//  BrowserTabRss.swift
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

extension BrowserTab: RSSSource {

    static let extractRssLinkScript = """
        Array.from(document.querySelectorAll("link[type*='rss'], link[type*='atom']"),
            link => new URL(link.getAttribute('href'), document.baseURI).href);
    """

    var rssUrls: [URL] {
        set {
            self.rssFeedUrls = newValue
            refreshRSSState()
        }
        get {
            self.rssFeedUrls
        }
    }

    var rssSubscriber: RSSSubscriber? {
        set {
            self.rssDelegate = newValue
            refreshRSSState()
        } get {
            self.rssDelegate
        }
    }

    @IBAction func subscribe(_ sender: NSObject? = nil) {
        if let rssSubscriber = self.rssSubscriber, !self.rssUrls.isEmpty {
            if let sender = sender, sender as? NSView != nil || sender as? NSCell != nil {
                rssSubscriber.subscribeToRSS(self.rssUrls, uiElement: sender)
            } else {
                rssSubscriber.subscribeToRSS(self.rssUrls)
            }
        }
    }

    func viewDidLoadRss() {
        refreshRSSState()
    }

    func refreshRSSState() {
        if rssSubscriber != nil && !self.rssUrls.isEmpty {
            //show RSS button
            self.showRssButton = true
        } else {
            //hide RSS button
            self.showRssButton = false
        }
    }

    func handleNavigationStartRss() { }

    func handleNavigationEndRss(success: Bool) {
        //use javascript to detect RSS feed link
        //TODO: deal with multiple links
        waitForAsyncExecution { finishHandler in
            self.webView.evaluateJavaScript(BrowserTab.extractRssLinkScript) { result, error in
                if error == nil, let result = result as? [String] {
                    //RSS feed link(s) detected
                    self.rssUrls = result.compactMap { URL(string: $0 as String) }
                } else {
                    //error or no rss url available
                    self.rssUrls = []
                }
                finishHandler()
            }
        }
    }
}
