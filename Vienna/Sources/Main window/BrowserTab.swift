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

    @IBOutlet private(set) weak var addressBarContainer: NSView!
    @IBOutlet private(set) weak var addressField: NSTextField!
    var webView: WKWebView = WKWebView()
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
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[addressBarContainer]-[webView]|", options: [], metrics: nil, views: ["webView": webView, "addressBarContainer": addressBarContainer]))
        //TODO: set webview options since this is not possible before macOS 12 in IB

		titleObservation = webView.observe(\WKWebView.title, options: NSKeyValueObservingOptions.new) { _, change in
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
		self.forward()
	}

	@IBAction func back(_ sender: Any) {
		self.back()
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

    func back() {
        self.webView.goBack()
    }

    func forward() {
        self.webView.goForward()
    }

    func pageDown() {
        self.webView.pageDown(nil)
    }

    func pageUp() {
        self.webView.pageUp(nil)
    }

    func searchFor(_ searchString: String, action: NSFindPanelAction) {

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
