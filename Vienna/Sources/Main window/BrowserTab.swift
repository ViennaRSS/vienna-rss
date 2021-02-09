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

class BrowserTab: NSViewController {

    // MARK: Properties

    let webView: CustomWKWebView

    @IBOutlet private(set) weak var addressBarContainer: NSView!
    @IBOutlet private(set) weak var addressField: NSTextField!
    @IBOutlet private(set) weak var backButton: NSButton!
    @IBOutlet private(set) weak var forwardButton: NSButton!
    @IBOutlet private(set) weak var reloadButton: NSButton!
    @IBOutlet private(set) weak var progressBar: LoadingIndicator?

    var webViewTopConstraint: NSLayoutConstraint!

    @IBOutlet private(set) weak var cancelButtonWidth: NSLayoutConstraint!
    @IBOutlet private(set) weak var reloadButtonWidth: NSLayoutConstraint!
    @IBOutlet private(set) weak var rssButtonWidth: NSLayoutConstraint!

    var url: URL? = nil {
        didSet {
            updateTabTitle()
            updateUrlTextField()
        }
    }

    var loadedTab: Bool = false

    var loading: Bool = false

    var loadingProgress: Double = 0 {
        didSet { updateVisualLoadingProgress() }
    }

    /// backing storage only, access via rssSubscriber property
    weak var rssDelegate: RSSSubscriber?
    /// backing storage only, access via rssUrl property
    var rssFeedUrls: [URL] = []

    var showRssButton: Bool = false

    var viewVisible: Bool = false

    private var titleObservation: NSKeyValueObservation?
    private var loadingObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?

    // MARK: object lifecycle

    init(_ request: URLRequest? = nil, config: WKWebViewConfiguration = WKWebViewConfiguration()) {

        self.webView = CustomWKWebView(configuration: config)

        if #available(macOS 10.14, *) {
            super.init(nibName: "BrowserTab", bundle: nil)
        } else {
            super.init(nibName: "BrowserTabWithLegacyAddressBar", bundle: nil)
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
            guard let newValue = change.newValue, newValue != nil else {
                return
            }
            self?.url = newValue
        }

        if let request = request {
            webView.load(request)
        }
    }

    @available(*, unavailable)
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

        // set up webview (not yet possible via interface builder)
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(webView, positioned: .below, relativeTo: addressBarContainer)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView]|", options: [], metrics: nil, views: ["webView": webView]))
        webViewTopConstraint = NSLayoutConstraint(item: self.view, attribute: .top, relatedBy: .equal, toItem: webView, attribute: .top, multiplier: -1, constant: 0)
        let webViewBottomConstraint = NSLayoutConstraint(item: webView, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1, constant: 0)
        self.view.addConstraints([webViewTopConstraint, webViewBottomConstraint])

        // title needs to be adjusted once view is loaded

        // reload button / cancel button layout is not determined yet
        self.loading = self.webView.isLoading

        // set up url displayed in address field
        if let url = webView.url {
            self.url = url
        }

        self.viewDidLoadRss()

        updateAddressBarButtons()

        updateWebViewInsets()

        // set up address bar handling
        addressField.delegate = self

        // set up navigation handling
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
            activateWebView()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.viewVisible = false
    }

}

// MARK: Tab functionality

extension BrowserTab: Tab {

    var tabUrl: URL? {
        get {
            self.url
        }
        set {
            self.url = newValue
            self.loadedTab = false
        }
    }

    var textSelection: String {
        webView.textSelection
    }

    var html: String {
        "" // TODO: get HTML and return
    }

    var isLoading: Bool {
        loading
    }

    func back() -> Bool {
        let couldGoBack = self.webView.goBack() != nil
        // title and url observation not triggered by goBack() -> manual setting
        self.url = self.webView.url
        updateTabTitle()
        return couldGoBack
    }

    func forward() -> Bool {
        let couldGoForward = self.webView.goForward() != nil
        // title observation not triggered by goForware() -> manual setting
        self.url = self.webView.url
        updateTabTitle()
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
        // webView.evaluateJavaScript("document.execCommand('HiliteColor', false, 'yellow')", completionHandler: nil)
        self.webView.search(searchString, upward: action == .previous)
    }

    func loadTab() {
        if self.isViewLoaded {
            self.addressField.stringValue = self.url?.absoluteString ?? ""
        }
        if let url = self.url {
            self.webView.load(URLRequest(url: url))
            loadedTab = true
            if self.isViewLoaded && self.view.window != nil {
                self.activateWebView()
            }
        } else {
            self.webView.load(URLRequest(url: URL.blank))
            self.activateAddressBar()
        }
    }

    func reloadTab() {
        if self.webView.url != nil {
            self.webView.reload()
            //to know what we have reloaded if the text was changed manually
            updateUrlTextField()
        } else {
            //when we have never loaded the webview yet, reload is actually load
            loadTab()
        }
    }

    func stopLoadingTab() {
        self.webView.stopLoading()
        //we must manually invoke navigation end callbacks
        self.handleNavigationEnd(success: false)
    }

    func decreaseTextSize() {
        // TODO: apple has not implemented this on macOS. There is a property webkit-text-size-adjust on iOS though.
    }

    func increaseTextSize() {
        // TODO: apple has not implemented this on macOS. There is a property webkit-text-size-adjust on iOS though.
    }

    func printPage() {
        // TODO: neither Javascript nor the native print methods work here. This is a webkit bug:
        // rdar://problem/36557179
        self.webView.printView(nil)
    }

    func activateAddressBar() {
        NSApp.mainWindow?.makeFirstResponder(addressField)
    }

    func activateWebView() {
        self.view.window?.makeFirstResponder(self.webView)
    }
}

// MARK: Webview navigation

extension BrowserTab: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        handleNavigationStart()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        // TODO: provisional navigation fail seems to translate to error in resolving URL or similar. Treat different from normal navigation fail
        handleNavigationEnd(success: false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        // TODO: show failure to load as page or symbol
        handleNavigationEnd(success: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        handleNavigationEnd(success: true)
    }

    func handleNavigationStart() {
        self.handleNavigationStartRss()
        updateAddressBarButtons()
    }

    func handleNavigationEnd(success: Bool) {
        self.handleNavigationEndRss(success: success)
        updateAddressBarButtons()
    }
}
