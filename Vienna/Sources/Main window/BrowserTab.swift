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

    @IBOutlet private(set) weak var addressBarPaddingView: NSView!
    @IBOutlet private(set) weak var addressBarContainer: NSView!
    @IBOutlet private(set) weak var addressField: NSTextField!
    @IBOutlet private(set) weak var backButton: NSButton!
    @IBOutlet private(set) weak var forwardButton: NSButton!
    @IBOutlet private(set) weak var reloadButton: NSButton!

	var tabUrl: URL? {
		didSet {
			self.title = tabUrl?.host ?? NSLocalizedString("New Tab", comment: "")
		}
	}

	var titleObservation: NSKeyValueObservation!

	init() {
        if #available(macOS 10.12, *) {
            super.init(nibName: nil, bundle: nil)
        } else {
            super.init(nibName: "BrowserTabBeforeMacOS12", bundle: nil)
        }
		titleObservation = webView.observe(\.title, options: .new) { _, change in
			self.title = (change.newValue ?? "") ?? ""
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

    override func viewDidLoad() {
        super.viewDidLoad()

		//set up webview
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(webView, positioned: .below, relativeTo: nil)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView]|", options: [], metrics: nil, views: ["webView": webView]))
		self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[addressBarContainer][webView]|", options: [], metrics: nil, views: ["webView": webView, "addressBarContainer": addressBarPaddingView as Any]))

		if let title = webView.title {
			self.title = title
		} else if let host = self.tabUrl?.host {
			self.title = host
		}
		if let url = webView.url {
			self.addressField.stringValue = url.absoluteString
		}

		//set up address bar handling
		addressField.delegate = self
    }

	deinit {
		titleObservation.invalidate()
	}
}

@available(OSX 10.10, *)
extension BrowserTab: NSTextFieldDelegate {
	//TODO: things like address suggestion etc

	@IBAction func loadPageFromAddressBar(_ sender: Any) {
		var theURL = addressField.stringValue
		if URL(string: theURL)?.scheme == nil {
			// If no '.' appears in the string, wrap it with 'www' and 'com'
			if !theURL.contains(".") {
				//TODO: search instead of assuming .com ending
				theURL = "www." + theURL + ".com"
			}
			theURL = "http://" + theURL
		}

		// cleanUpUrl is a hack to handle Internationalized Domain Names. WebKit handles them automatically, so we tap into that.
		let urlToLoad = cleanedUpUrlFromString(theURL)
		if urlToLoad != nil {
			//set url and load immediately, because action was invoked by user
			self.tabUrl = urlToLoad
			self.loadTab()
		} else {
			self.activateAddressBar()
		}

		self.tabUrl = URL(string: addressField.stringValue)
		self.loadTab()
	}

	@IBAction func reload(_ sender: Any) {
		self.reloadTab()
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
        ""
    }

    var isLoading: Bool {
		webView.isLoading
    }

    func back() -> Bool {
		self.webView.goBack() != nil
    }

    func forward() -> Bool {
		self.webView.goForward() != nil
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

    func searchFor(_ searchString: String, action: NSFindPanelAction) {
		// TODO
    }

	func loadTab() {
		if self.isViewLoaded {
			self.addressField.stringValue = self.tabUrl?.absoluteString ?? ""
		}
		if let url = self.tabUrl {
			self.webView.load(URLRequest(url: url))
		}
	}

	func reloadTab() {
		self.webView.reload()
    }

    func stopLoadingTab() {
        self.webView.stopLoading()
    }

    func decreaseTextSize() {
        //TODO
    }

    func increaseTextSize() {
        //TODO
    }

    func print() {
        //TODO
    }

    func activateAddressBar() {
        NSApp.mainWindow?.makeFirstResponder(addressField)
    }
}
