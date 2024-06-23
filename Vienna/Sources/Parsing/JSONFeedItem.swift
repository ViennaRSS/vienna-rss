//
//  JSONFeedItem.swift
//  Vienna
//
//  Copyright 2022-2023 Eitot
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

@objc(VNAJSONFeedItem)
class JSONFeedItem: NSObject, FeedItem, Decodable {

    // JSON Feed has the `id` key which is required. The specification insists
    // that items without an `id` should be discard.
    var guid: String

    // The `title` key is optional.
    var title: String?

    // JSON Feed has two possible keys: `author` and `authors`. `author` is
    // deprecated in version 1.1, but still allowed. `authors` replaces it. If
    // both keys are present, `authors` should have precedence. If neither is
    // present, the top-level `author` and `authors` keys can be used instead.
    var authors: String?

    // JSON Feed has two possible keys: `content_html` and `content_text` which
    // are mutually exclusive. At least one key must be present.
    var content: String

    // JSON Feed has `date_published` and `date_modified` keys, neither is
    // required. If present, they should be date strings in RFC 3339 format.
    var modifiedDate: Date?

    // The `url` key is optional. The `id` key might be a URL too, so it could
    // be a fallback.
    var url: String?

    // The `attachments` key is optional.
    var enclosure: String?

    // MARK: Decodable

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case authors
        case author
        case contentHTML = "content_html"
        case contentText = "content_text"
        case modifiedDate = "date_modified"
        case publishedDate = "date_published"
        case url
        case attachments
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guid = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)

        do {
            let authors = try container.decode([Author].self, forKey: .authors).map { $0.name }
            if #available(macOS 12, *) {
                self.authors = authors.formatted(.list(type: .and, width: .narrow))
            } else {
                self.authors = authors.joined(separator: ", ")
            }
        } catch DecodingError.keyNotFound, DecodingError.valueNotFound {
            authors = try container.decodeIfPresent(String.self, forKey: .author)
        }

        if authors == nil {
            do {
                let superDecoder = try container.superDecoder()
                let superContainer = try superDecoder.container(keyedBy: JSONFeed.CodingKeys.self)
                let authors = try superContainer.decode([Author].self, forKey: .authors).map { $0.name }
                if #available(macOS 12, *) {
                    self.authors = authors.formatted(.list(type: .and, width: .narrow))
                } else {
                    self.authors = authors.joined(separator: ", ")
                }
            } catch DecodingError.keyNotFound, DecodingError.valueNotFound {
                authors = try container.decodeIfPresent(String.self, forKey: .author)
            }
        }

        do {
            content = try container.decode(String.self, forKey: .contentHTML)
        } catch {
            content = try container.decode(String.self, forKey: .contentText)
        }

        modifiedDate = try container.decodeIfPresent(Date.self, forKey: .modifiedDate)

        do {
            url = try container.decode(URL.self, forKey: .url).absoluteString
        } catch {
            // The `id` key might be a valid URL.
            url = URL(string: guid)?.absoluteString
        }

        // TODO: Handle multiple attachments
        let attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments)
        self.enclosure = attachments?.first?.url.absoluteString
    }

}

private struct Author: Decodable {

    // The `name` key is required if neither of the other two keys – `url` and
    // `avatar` – is set, otherwise it is optional. Vienna is only interested in
    // the `name` key, so if that key is not set, the decoding should fail.
    var name: String

}

private struct Attachment: Decodable {

    // The `url` key is required.
    var url: URL

}
