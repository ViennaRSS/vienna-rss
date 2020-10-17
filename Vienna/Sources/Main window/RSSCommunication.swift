//
//  RSSCommunication.swift
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

protocol RSSSource: AnyObject {
    var rssSubscriber: RSSSubscriber? { get set }
}

protocol RSSSubscriber: AnyObject {

    /// callback to ask the subscriber whether it is interested in getting a subscribe call for a certain URL
    /// called every time a feed URL is found (may repeatedly call for same URL)
    /// - Parameter url: the url that the source potentially wants to subscribe to
    func isInterestedIn(_ url: URL) -> Bool

    /// callback to the RSS subscriber when the browser user wants to subscribe to a feed
    /// - Parameter urls: non-empty url array containing Atom or RSS feed urls
    func subscribeToRSS(_ urls: [URL])

    /// callback to the RSS subscriber when the browser user triggers subscription to a feed by clicking ui element
    /// - Parameters:
    ///   - urls: non-empty url array containing Atom or RSS feed urls
    ///   - uiElement: the element that triggered the subscription request
    func subscribeToRSS(_ urls: [URL], uiElement: NSObject)
}

extension RSSSubscriber {

    //default: "interested" in all feeds
    func isInterestedIn(_ url: URL) -> Bool { true }

    //default: ignore ui element which triggered the subscribe request
    func subscribeToRSS(_ urls: [URL], uiElement: NSObject) {
        self.subscribeToRSS(urls)
    }
}
