//
//  BrowserTab+RSSSource.swift
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

    static let extractHTMLSource = "document.documentElement.outerHTML"

    var rssUrls: [URL] {
        get {
            self.rssFeedUrls
        }
        set {
            self.rssFeedUrls = newValue
            refreshRSSState()
        }
    }

    var rssSubscriber: (any RSSSubscriber)? {
        get {
            self.rssDelegate
        }
        set {
            self.rssDelegate = newValue
            refreshRSSState()
        }
    }

    @IBAction private func subscribe(_ sender: Any) {
        if let rssSubscriber = self.rssSubscriber, !self.rssUrls.isEmpty {
            if let sender = sender as? NSObject {
                rssSubscriber.subscribeToRSS(self.rssUrls, uiElement: sender)
            } else {
                rssSubscriber.subscribeToRSS(self.rssUrls)
            }
        }
    }

    @objc
    func viewDidLoadRss() {
        registerNavigationEndHandler { [weak self] success in self?.handleNavigationEndRss(success: success) }
        refreshRSSState()
    }

    func refreshRSSState() {
        if rssSubscriber != nil && !self.rssUrls.isEmpty {
            // show RSS button
            self.showRssButton = true
        } else {
            // hide RSS button
            self.showRssButton = false
        }
    }

    func handleNavigationEndRss(success: Bool) {
        guard success else {
            self.rssUrls = []
            return
        }
        // use javascript to detect RSS feed link
        // TODO: deal with multiple links
        waitForAsyncExecution(until: DispatchTime.now() + DispatchTimeInterval.milliseconds(200)) { [weak self] finishHandler in
            self?.webView.evaluateJavaScript(BrowserTab.extractHTMLSource) { result, error in
                defer { finishHandler() }
                if let html = result as? String, let data = html.data(using: .utf8), let baseUrl = self?.url, error == nil {
                    let discoverer = FeedDiscoverer(data: data, baseURL: baseUrl)
                    self?.rssUrls = discoverer.feedURLs().map(\.absoluteURL)
                } else {
                    // error or conversion problem
                    self?.rssUrls = []
                }
            }
        }
    }
}
