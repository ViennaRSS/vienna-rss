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

// MARK: State

@available(OSX 10.10, *)
class BrowserTab: NSViewController {

    // MARK: Properties

	let webView: CustomWKWebView = {
		let prefs = WKPreferences()
		prefs.javaScriptEnabled = true
		prefs.javaScriptCanOpenWindowsAutomatically = true
		prefs.plugInsEnabled = true
		let config = WKWebViewConfiguration()
		config.preferences = prefs
        if #available(OSX 10.11, *) {
            // for useragent, we mimic the installed version of Safari and add our own identifier
            let shortSafariVersion = Bundle(path: "/Applications/Safari.app")?.infoDictionary?["CFBundleShortVersionString"] as? String
            let viennaVersion = (NSApp as? ViennaApp)?.applicationVersion?.prefix(while: { character in character != " " })
            config.applicationNameForUserAgent = "Version/\(shortSafariVersion ?? "9.1") Safari/605 Vienna/\(viennaVersion ?? "3.5+")"
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
    @IBOutlet private(set) weak var progressBar: LoadingIndicator?

    @IBOutlet private(set) weak var cancelButtonWidth: NSLayoutConstraint!
    @IBOutlet private(set) weak var reloadButtonWidth: NSLayoutConstraint!
    @IBOutlet private(set) weak var rssButtonWidth: NSLayoutConstraint!

	var url: URL? = nil {
		didSet {
            if self.url != webView.url || self.url == nil {
                self.title = self.url?.host ?? NSLocalizedString("New Tab", comment: "")
            }
            self.addressField?.stringValue = self.url?.absoluteString ?? ""
		}
	}

    var loadedTab: Bool = false

    var loading: Bool = false

    /// backing storage only, access via rssSubscriber property
    weak var rssDelegate: RSSSubscriber?
    /// backing storage only, access via rssUrl property
    var rssFeedUrl: URL?

    var showRssButton: Bool = false

    var viewVisible: Bool = false

	var titleObservation: NSKeyValueObservation?
    var loadingObservation: NSKeyValueObservation?
    var progressObservation: NSKeyValueObservation?
    var urlObservation: NSKeyValueObservation?

    // MARK: object lifecycle

    init() {
        if #available(macOS 10.12, *) {
            super.init(nibName: nil, bundle: nil)
        } else {
            super.init(nibName: "BrowserTabBeforeMacOS12", bundle: nil)
        }
        titleObservation = webView.observe(\.title, options: .new) { [weak self] _, change in
            guard let newValue = change.newValue ?? "", !newValue.isEmpty else {
                return
            }
            self?.title = newValue
        }
        loadingObservation = webView.observe(\.isLoading, options: .new) { [weak self] _, change in
            guard let newValue = change.newValue else {
                return
            }
            self?.loading = newValue
        }
        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, change in
            guard let newValue = change.newValue else {
                return
            }
            self?.loadingProgress = newValue
        }
        urlObservation = webView.observe(\.url, options: .new) { [weak self] _, change in
            guard let newValue = change.newValue else {
                return
            }
            self?.url = newValue
        }
    }

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		titleObservation?.invalidate()
        loadingObservation?.invalidate()
        progressObservation?.invalidate()
        urlObservation?.invalidate()
	}

    // MARK: ViewController lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        //set up webview (not yet possible via interface builder)
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(webView, positioned: .below, relativeTo: nil)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView]|", options: [], metrics: nil, views: ["webView": webView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[addressBarContainer][webView]|", options: [], metrics: nil, views: ["webView": webView, "addressBarContainer": addressBarContainer as Any]))

        //title needs to be adjusted once view is loaded

        //reload button / cancel button layout is not determined yet
        self.loading = self.webView.isLoading

        //set up url displayed in address field
        if let url = webView.url {
            self.url = url
        }

        self.viewDidLoadRss()

        updateAddressBarLayout()

        //set up address bar handling
        addressField.delegate = self

        //set up navigation handling
        webView.navigationDelegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        addressBarContainer.layoutSubtreeIfNeeded()
        self.viewVisible = true
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if self.loadedTab {
            self.view.window?.makeFirstResponder(self.webView)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.viewVisible = false
    }
}

// MARK: Tab functionality

@available(OSX 10.10, *)
extension BrowserTab: Tab {

    var tabUrl: URL? {
        set {
            self.url = newValue
            self.loadedTab = false
        }
        get {
            self.url
        }
    }

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
        "" //TODO: get HTML and return
    }

    var isLoading: Bool {
		loading
    }

    func back() -> Bool {
		let couldGoBack = self.webView.goBack() != nil
        //title observation not triggered by goBack() -> manual setting
        self.url = self.webView.url
        self.title = self.webView.title
        return couldGoBack
    }

    func forward() -> Bool {
		let couldGoForward = self.webView.goForward() != nil
        //title observation not triggered by goForware() -> manual setting
        self.url = self.webView.url
        self.title = self.webView.title
        return couldGoForward
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
            self.addressField.stringValue = self.url?.absoluteString ?? ""
        }
        if let url = self.url {
            self.webView.load(URLRequest(url: url))
            loadedTab = true
            if self.isViewLoaded && self.view.window != nil {
                self.view.window?.makeFirstResponder(self.webView)
            }
        } else {
            //TODO: this seems to wipe history, which we do not want
            self.webView.loadHTMLString("", baseURL: nil)
            self.activateAddressBar()
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

    func printPage() {
        //TODO: neither Javascript nor the native print methods work here. This is a webkit bug:
        // rdar://problem/36557179
        self.webView.printView(nil)
    }

    func activateAddressBar() {
        NSApp.mainWindow?.makeFirstResponder(addressField)
    }
}

// MARK: Webview navigation

@available(OSX 10.10, *)
extension BrowserTab: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        handleNavigationStart()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        //TODO: provisional navigation fail seems to translate to error in resolving URL or similar. Treat different from normal navigation fail
        handleNavigationEnd(success: false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        //TODO: show failure to load as page or symbol
        handleNavigationEnd(success: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        handleNavigationEnd(success: true)
    }

    func handleNavigationStart() {
        self.handleNavigationStartRss()
        updateAddressBarLayout()
    }

    func handleNavigationEnd(success: Bool) {
        self.handleNavigationEndRss(success: success)
        updateAddressBarLayout()
    }
}
