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
extension ArticleConverter {

    func setup() {
        //update the article content style when the active display style has changed
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "MA_Notify_StyleChange"), object: nil, queue: nil) { [weak self] notification in
            self?.initForCurrentStyle()
        }

        self.initForCurrentStyle()
    }

    func initForCurrentStyle() {
        self.initForStyle(Preferences.standard.displayStyle)
    }

    func initForStyle(_ name: String) {
        guard let pathString = ArticleStyleLoader.stylesMap[name] as? String else {
            self.styleChangeFailed(name)
            return
        }
        let path = URL(fileURLWithPath: pathString)
        self.initForStyle(at: path)
    }

    func initForStyle(at path: URL) {
        fatalError("must be overridden by subclasses")
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
        Preferences.standard.setDisplayStyle("Default", withNotification: false)
    }
}
