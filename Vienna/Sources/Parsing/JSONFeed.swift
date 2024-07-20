//
//  JSONFeed.swift
//  Vienna
//
//  Copyright 2018, 2022-2023 Eitot
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

@objc(VNAJSONFeed)
class JSONFeed: NSObject, Feed, Decodable {

    // The `title` key is required.
    var title: String

    // The `description` key is optional.
    var feedDescription: String?

    // The `home_page_url` key is optional.
    var homePageURL: String?

    // JSON Feed has no key for this at the feed level.
    var modificationDate: Date?

    // The `items` key is required (but the array may be empty).
    var items: [any FeedItem]

    // MARK: Decodable

    enum CodingKeys: String, CodingKey {
        case title
        case feedDescription = "description"
        case homePageURL = "home_page_url"
        case publicationDate = "date_published"
        case modificationDate = "date_modified"
        case items

        // These keys are only used by JSONFeedItem
        case authors
        case author
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        feedDescription = try container.decodeIfPresent(String.self, forKey: .feedDescription)
        homePageURL = try container.decodeIfPresent(URL.self, forKey: .homePageURL)?.absoluteString
        items = try container.decode([JSONFeedItem].self, forKey: .items)
    }

}
