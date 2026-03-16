//
//  BrowserTab+Interface.swift
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

import Cocoa

extension BrowserTab {

    // MARK: User Interaction

    @IBAction private func loadPageFromAddressBar(_ sender: Any) {
        let enteredUrl = addressField.stringValue

        guard !enteredUrl.isEmpty else {
            tabUrl = nil
            self.loadTab()
            return
        }

        cleanAndLoad(url: enteredUrl)
    }

    @IBAction private func reload(_ sender: Any) {
        self.reloadTab()
    }

    @IBAction private func cancel(_ sender: Any) {
        self.stopLoadingTab()
    }

    @IBAction private func forward(_ sender: Any) {
        _ = self.forward()
    }

    @IBAction private func back(_ sender: Any) {
        _ = self.back()
    }

    private func cleanAndLoad(url: String) {

        var cleanedUrl = url

        if URL(string: cleanedUrl)?.scheme == nil {
            // If no '.' appears in the string, wrap it with 'www' and 'com'
            if !cleanedUrl.contains(".") {
                // TODO: search instead of assuming .com ending
                cleanedUrl = "www." + cleanedUrl + ".com"
            }
            cleanedUrl = "http://" + cleanedUrl
        }

        // cleanUpUrl is a hack to handle Internationalized Domain Names. WebKit handles them automatically, so we tap into that.
        let urlToLoad = cleanedUpUrlFromString(cleanedUrl) // TODO: remove tight coupling to HelperFunctions

        // set url and load immediately, because action was invoked by user
        self.tabUrl = urlToLoad
        self.loadTab()
    }

    // MARK: UI Updates

    func updateVisualLoadingProgress() {
        guard let progressBar = progressBar else {
            return
        }
        let loadingProgress = CGFloat(self.loadingProgress)
        // Small value for backwards animation to avoid default duration
        let duration = progressBar.currentLoadingProgress < loadingProgress ? 0.3 : 0.001
        progressBar.setLoadingProgress(loadingProgress, animationDuration: duration)
        if loadingProgress == 1.0 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.4) {
                progressBar.isHidden = true
            }
        } else {
            progressBar.isHidden = false
        }
    }

    func updateAddressBarButtons() {

        cancelButtonWidth?.constant = loading ? 30 : 0
        reloadButtonWidth?.constant = loading ? 0 : 30

        if showRssButton {
            // show rss button
            rssButtonWidth?.constant = 40
        } else {
            // hide rss button
            rssButtonWidth?.constant = 0
        }

        addressBarContainer?.needsLayout = true

        if viewVisible {
            NSAnimationContext.runAnimationGroup({_ in
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.allowsImplicitAnimation = true
                self.addressBarContainer?.layoutSubtreeIfNeeded()
            }, completionHandler: nil)
        } else {
            self.addressBarContainer?.layoutSubtreeIfNeeded()
        }
    }

    func hideAddressBar(_ hide: Bool, animated: Bool = false) {
        // We need to use the optional here in case view is not yet loaded
        addressBarContainer?.isHidden = hide
        updateWebViewInsets()
        // TODO: animated show / hide
    }

    func updateWebViewInsets() {
        if let addressBarContainer = addressBarContainer {
            let distanceToTop = addressBarContainer.isHidden ? 0 : addressBarContainer.frame.height
            if #available(macOS 10.14, *) {
                if webView.responds(to: #selector(setter: WKWebView._automaticallyAdjustsContentInsets)),
                   webView.responds(to: #selector(setter: WKWebView._topContentInset)) {
                    webView._automaticallyAdjustsContentInsets = false
                    webView._topContentInset = distanceToTop
                }
            } else {
                self.webViewTopConstraint.constant = distanceToTop
            }
        }
    }

    func updateTabTitle() {
        if self.url != webView.url || self.url == nil {
            // Currently loading (the first time), webview title not yet correct / available
            self.title = self.url?.host ?? NSLocalizedString("New Tab", comment: "")
        } else if let title = self.webView.title, !title.isEmpty {
            self.title = title
        } else {
            // Webview is about:blank or empty
            self.title = NSLocalizedString("New Tab", comment: "")
        }
    }

    func updateUrlTextField() {
        if let url = self.url, url != URL.blank {
            self.addressField?.stringValue = url.absoluteString
        } else {
            self.addressField?.stringValue = ""
        }
    }
}

// MARK: Address Bar Delegate

extension BrowserTab: NSTextFieldDelegate {
    // TODO: things like address suggestion etc
    // TODO: restore url string when user presses escape in textfield, make webview first responder
}

// MARK: hover link ui

extension BrowserTab: CustomWKHoverUIDelegate {

    func viewDidLoadHoverLinkUI() {
        registerNavigationStartHandler { [weak self] in
            //TODO is it really necessary to do this on every navigation start instead of only once after webview initialization?
            self?.webView.hoverUiDelegate = self
            self?.statusBar?.label = ""
        }
    }

    func hovered(link: String?) {
        guard let statusBar = statusBar else {
            return
        }
        statusBar.label = link
    }
}
