//
//  ArticleConverter.swift
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

@objc
public class WebViewArticleConverter: ArticleConverter {

    override func initForStyle(at path: URL) {

        guard let templateString = try? String(contentsOf: path.appendingPathComponent("template.html")),
            !templateString.isEmpty else {
            self.styleChangeFailed(path.absoluteString)
            return
        }

        self.htmlTemplate = templateString

        self.cssStylesheet = cleanedUpUrlFromString("file://localhost" + path.appendingPathComponent("stylesheet.css").path)?.absoluteString ?? ""

        let jsScriptPath = path.appendingPathComponent("script.js").path
        if FileManager.default.fileExists(atPath: jsScriptPath) {
            self.jsScript = cleanedUpUrlFromString("file://localhost" + jsScriptPath)?.absoluteString ?? ""
        } else {
            self.jsScript = ""
        }

        let nonEmptyRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\S")
        let stringRange = { (subString: String.SubSequence) in
            NSRange(location: 0, length: subString.utf8.count) }
        let nonEmptyMatchExists = { (subString: String.SubSequence) in
            nonEmptyRegex?.firstMatch(in: String(subString), range: stringRange(subString)) != nil }

        let firstNonEmptyLine = htmlTemplate.split(separator: "\n").first(where: nonEmptyMatchExists)?.lowercased() ?? ""
        guard !(firstNonEmptyLine.starts(with: "<html>") || firstNonEmptyLine.starts(with: "<!doctype")) else {
            self.styleChangeFailed(path.absoluteString)
            return
        }

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MA_Notify_ArticleViewChange"), object: nil)
    }
}
