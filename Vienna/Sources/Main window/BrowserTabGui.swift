//
//  BrowserTabGui.swift
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

//MARK: User Interaction

extension BrowserTab {

    @IBAction func loadPageFromAddressBar(_ sender: Any) {
        let enteredUrl = addressField.stringValue

        guard !enteredUrl.isEmpty else {
            tabUrl = nil
            self.loadTab()
            return
        }

        cleanAndLoad(url: enteredUrl)
    }


    @IBAction func reload(_ sender: Any) {
        self.reloadTab()
    }

    @IBAction func cancel(_ sender: Any) {
        self.stopLoadingTab()
    }

    @IBAction func forward(_ sender: Any) {
        _ = self.forward()
    }

    @IBAction func back(_ sender: Any) {
        _ = self.back()
    }

    private func cleanAndLoad(url: String) {

        var cleanedUrl = url

        if URL(string: cleanedUrl)?.scheme == nil {
            // If no '.' appears in the string, wrap it with 'www' and 'com'
            if !cleanedUrl.contains(".") {
                //TODO: search instead of assuming .com ending
                cleanedUrl = "www." + cleanedUrl + ".com"
            }
            cleanedUrl = "http://" + cleanedUrl
        }

        // cleanUpUrl is a hack to handle Internationalized Domain Names. WebKit handles them automatically, so we tap into that.
        let urlToLoad = cleanedUpUrlFromString(cleanedUrl)

        //set url and load immediately, because action was invoked by user
        self.tabUrl = urlToLoad
        self.loadTab()
    }
}

// MARK: Address Bar Delegate

@available(OSX 10.10, *)
extension BrowserTab: NSTextFieldDelegate {
    //TODO: things like address suggestion etc
    //TODO: restore url string when user presses escape in textfield, make webview first responder

}
