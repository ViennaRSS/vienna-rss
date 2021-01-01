//
//  BrowserTab.swift
//  Vienna
//
//  Copyright 2018
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

@available(OSX 10.10, *)
class BrowserTab: NSViewController {

	let webView: CustomWKWebView = {
		let prefs = WKPreferences()
		prefs.javaScriptEnabled = true
		prefs.javaScriptCanOpenWindowsAutomatically = true
		prefs.plugInsEnabled = true
		let config = WKWebViewConfiguration()
		config.preferences = prefs
		if #available(OSX 10.11, *) {
			config.applicationNameForUserAgent = "vienna-rss"
			config.allowsAirPlayForMediaPlayback = true
		}
		if #available(OSX 10.12, *) {
			config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.all
		}
		let wv = CustomWKWebView(frame: .zero, configuration: config)
		wv.allowsMagnification = true
		wv.allowsBackForwardNavigationGestures = true
		if #available(OSX 10.11, *) {
			wv.allowsLinkPreview = true
		}
		return wv
	}()

    @IBOutlet private(set) weak var addressBarContainer: NSView!
    @IBOutlet private(set) weak var addressField: NSTextField!
    @IBOutlet private(set) weak var backButton: NSButton!
    @IBOutlet private(set) weak var forwardButton: NSButton!
    @IBOutlet private(set) weak var reloadButton: NSButton!

    var url: URL?

	var titleObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

		//set up webview
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(webView, positioned: .below, relativeTo: nil)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView]|", options: [], metrics: nil, views: ["webView": webView]))
        //TODO: set top constraint to view top, insets to webview
		self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[addressBarContainer]-[webView]|", options: [], metrics: nil, views: ["webView": webView, "addressBarContainer": addressBarContainer as Any]))

		self.title = webView.title
		titleObservation = webView.observe(\.title, options: [.new]) { _, change in
			self.title = change.newValue ?? nil
		}

		//set up address bar handling
		addressField.delegate = self
    }

	deinit {
		titleObservation?.invalidate()
	}
}

@available(OSX 10.10, *)
extension BrowserTab: NSTextFieldDelegate {
	//TODO: things like address suggestion etc

	@IBAction func loadPageFromAddressBar(_ sender: Any) {
		self.url = URL(string: addressField.stringValue)
		self.load()
	}

	@IBAction func reload(_ sender: Any) {
		self.reload()
	}

	@IBAction func forward(_ sender: Any) {
		_ = self.forward()
	}

	@IBAction func back(_ sender: Any) {
		_ = self.back()
	}
}

@available(OSX 10.10, *)
extension BrowserTab: Tab {

    var textSelection: String {
        return ""
    }

    var html: String {
        return ""
    }

    var loading: Bool {
		return webView.isLoading
    }

    func back() -> Bool {
		return self.webView.goBack() != nil
    }

    func forward() -> Bool {
		return self.webView.goForward() != nil
    }

    func pageDown() -> Bool {
		let canPageDown = self.webView.canScrollDown
        self.webView.pageDown(nil)
		return canPageDown
    }

    func pageUp() -> Bool {
		let canPageUp = self.webView.canScrollUp
        self.webView.pageUp(nil)
		return canPageUp
    }

    func searchFor(_ searchString: String, action: NSFindPanelAction) -> Bool {
		return false
    }

    func load() {
        if let url = self.url {
            self.webView.load(URLRequest(url: url))
        }
    }

	func reload() {
        self.webView.reload()
    }

    func stopLoading() {
        self.webView.stopLoading()
    }

    func decreaseTextSize() {

    }

    func increaseTextSize() {

    }

    func print() {

    }
}
