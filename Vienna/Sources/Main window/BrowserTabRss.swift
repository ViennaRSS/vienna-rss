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

    var rssUrl: URL? {
        set {
            self.rssFeedUrl = newValue
            refreshRSSState()
        }
        get {
            return self.rssFeedUrl
        }
    }

    var rssSubscriber: RSSSubscriber? {
        set {
            self.rssDelegate = newValue
            refreshRSSState()
        } get {
            return self.rssDelegate
        }
    }

    @IBAction func subscribe(_ sender: Any) {
        self.rssSubscriber?.subscribeToRSS(self.rssUrl)
    }

    func viewDidLoadRss() {
        refreshRSSState()
    }

    func refreshRSSState() {
        if rssUrl != nil /*&& rssSubscriber != nil*/ {
            //show RSS button
            self.showRssButton = true
        } else {
            //hide RSS button
            self.showRssButton = false
        }
    }

    func handleNavigationStartRss() {

    }

    func handleNavigationEndRss(success: Bool) {
        //use javascript to detect RSS feed link
        waitForAsyncExecution { finishHandler in
            self.webView.evaluateJavaScript("document.querySelector(\"link[type*='rss'], link[type*='atom']\").getAttribute('href')") { result, error in
                if error == nil, let result = result as? String {
                    //RSS feed link detected
                    self.rssUrl = URL(string: result as String)
                } else {
                    //error or no rss url available
                    self.rssUrl = nil
                }
                finishHandler()
            }
        }
    }
}
