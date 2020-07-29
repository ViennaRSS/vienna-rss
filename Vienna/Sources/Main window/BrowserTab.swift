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

    var loadedUrl: Bool = false

	var titleObservation: NSKeyValueObservation!

	init() {
        if #available(macOS 10.12, *) {
            super.init(nibName: nil, bundle: nil)
        } else {
            super.init(nibName: "BrowserTabBeforeMacOS12", bundle: nil)
        }
		titleObservation = webView.observe(\.title, options: .new) { _, change in
            guard let newValue = change.newValue ?? "", !newValue.isEmpty else {
                return
            }
            self.title = newValue
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

        if let title = webView.title, !title.isEmpty {
			self.title = title
        } else if self.title == nil || self.title!.isEmpty, let host = self.tabUrl?.host {
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
        var text = ""
        waitForAsyncExecution(until: DispatchTime.now() + DispatchTimeInterval.seconds(1)) { finishHandler in
            self.webView.evaluateJavaScript("window.getSelection().getRangeAt(0).toString()") { res, _ in
                guard let selectedText = res as? String else {
                    return
                }
                text = selectedText
                finishHandler()
            }
        }
        return text
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
        //webView.evaluateJavaScript("document.execCommand('HiliteColor', false, 'yellow')", completionHandler: nil)
        let searchUpward = action == .previous ? "true" : "false"
        webView.evaluateJavaScript("window.find(textToFind='\(searchString)', matchCase=false, searchUpward=\(searchUpward), wrapAround=true)", completionHandler: nil)
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
        //TODO: apple has not implemented this on macOS. There is a property webkit-text-size-adjust on iOS though.
    }

    func increaseTextSize() {
        //TODO: apple has not implemented this on macOS. There is a property webkit-text-size-adjust on iOS though.
    }

    func print() {
        //TODO: neither Javascript nor the native print methods work here. This is a webkit bug:
        // rdar://problem/36557179
        self.webView.printView(nil)
    }

    func activateAddressBar() {
        NSApp.mainWindow?.makeFirstResponder(addressField)
    }
}
