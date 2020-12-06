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

protocol StyleListener {
    var htmlTemplate: String { get set }
    var cssStylesheet: URL { get set }
    var jsScript: URL { get set }

}

@objc
extension ArticleConverter {

    func setupStyle() {
        //update the article content style when the active display style has changed
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "MA_Notify_StyleChange"), object: nil, queue: nil) { [weak self] notification in
            self?.initForCurrentStyle()
        }

        self.initForCurrentStyle()
    }

    func initForCurrentStyle() {
        self.initForStyle(Preferences.standard().displayStyle)
    }

    func initForStyle(_ name: String) {
        guard let pathString = ArticleStyleLoader.stylesMap[name] as? String else {
            self.styleChangeFailed(name)
            return
        }

        let path = URL(fileURLWithPath: pathString)

        guard let templateString = try? String(contentsOf: path.appendingPathComponent("template.html")),
            !templateString.isEmpty else {
            self.styleChangeFailed(name)
            return
        }

        htmlTemplate = templateString

        cssStylesheet = cleanedUpUrlFromString("file://localhost" + path.appendingPathComponent("stylesheet.css").path)?.absoluteString ?? ""

        let jsScriptPath = path.appendingPathComponent("script.js").path
        if FileManager.default.fileExists(atPath: jsScriptPath) {
            jsScript = cleanedUpUrlFromString("file://localhost" + jsScriptPath)?.absoluteString ?? ""
        } else {
            jsScript = ""
        }

        let nonEmptyRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\S")
        let stringRange = { (s: String.SubSequence) in
            NSRange(location: 0, length: s.utf8.count) }
        let nonEmptyMatchExists = { (s: String.SubSequence) in
            nonEmptyRegex?.firstMatch(in: String(s), range: stringRange(s)) != nil }

        let firstNonEmptyLine = htmlTemplate.split(separator: "\n").first(where: nonEmptyMatchExists)?.lowercased() ?? ""
        guard !(firstNonEmptyLine.starts(with: "<html>") || firstNonEmptyLine.starts(with: "<!doctype")) else {
            self.styleChangeFailed(name)
            return
        }

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MA_Notify_ArticleViewChange"), object: nil)
    }

    func styleChangeFailed(_ name: String) {
        // If the template is invalid, revert to the default style
        // which should ALWAYS be valid.
        assert(name != "Default", "Default style is corrupted!")

        // Warn the user.
        let title = NSLocalizedString("The style %@ appears to be missing or corrupted", comment: "")
            .replacingOccurrences(of: "%@", with: name)
        let body = NSLocalizedString("The Default style will be used instead.", comment: "")

        runOKAlertPanelPlain(title, body)

        // We need to reset the preferences without firing off a notification since we want the
        // style change to happen immediately.
        Preferences.standard().setDisplayStyle("Default", withNotification: false)
    }
}
