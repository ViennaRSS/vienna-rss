//
//  WebKitArticleConverter.swift
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

public class WebKitArticleConverter: ArticleConverter {
    func prepareArticleDisplay(_ articles: [Article]) -> (htmlPath: URL, accessPath: URL) {

        guard !articles.isEmpty, let supportPathString = Bundle.main.sharedSupportPath else {
            fatalError("an empty articles array cannot be presented, and access to the styles directory must be granted")
        }

        let supportPathUrl = URL(fileURLWithPath: supportPathString)
        let stylesPath = supportPathUrl.appendingPathComponent("Styles").appendingPathComponent("Default.viennastyle")

        let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let targetDirectory = URL(fileURLWithPath: cachesPath[0])

        let htmlPath = targetDirectory.appendingPathComponent("article.html")

        //TODO: move all files from styles to targetDirectory, fix relative references, write expanded html template to targetDirectory/article.html

        return (htmlPath: htmlPath, accessPath: targetDirectory)
    }
}
