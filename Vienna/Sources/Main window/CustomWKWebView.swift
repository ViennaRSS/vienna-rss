//
//  CustomWKWebView.swift
//  Vienna
//
//  Copyright 2019
//

import Cocoa
import WebKit

class CustomWKWebView: WKWebView {

    static let clickListenerName = "clickListener"
    static let jsErrorListenerName = "errorListener"
    @objc static let mouseDidEnterName = "mouseDidEnter"
    @objc static let mouseDidExitName = "mouseDidExit"

    // store weakly here because contentController retains listener
    weak var contextMenuListener: CustomWKWebViewContextMenuListener?

    weak var contextMenuProvider: CustomWKUIDelegate? {
        didSet {
            self.uiDelegate = contextMenuProvider
        }
    }

    @objc weak var hoverUiDelegate: CustomWKHoverUIDelegate? {
        didSet {
            resetHoverUiListener()
        }
    }

    var canScrollDown: Bool {
        evaluateScrollPossibilities().scrollDownPossible
    }
    var canScrollUp: Bool {
        evaluateScrollPossibilities().scrollUpPossible
    }
    var textSelection: String {
        getTextSelection()
    }

    private var useJavaScriptObservation: NSKeyValueObservation?

    override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {

        // preferences
        let prefs = configuration.preferences
        prefs.javaScriptCanOpenWindowsAutomatically = true

        if #available(macOS 12.3, *) {
            prefs.isElementFullscreenEnabled = true
        } else if prefs.responds(to: #selector(setter: WKPreferences._isFullScreenEnabled)) {
            prefs._isFullScreenEnabled = true
        }

        #if DEBUG
        if prefs.responds(to: #selector(setter: WKPreferences._developerExtrasEnabled)) {
            prefs._developerExtrasEnabled = true
        }
        #endif

        useJavaScriptObservation = Preferences.standard.observe(\.useJavaScript, options: [.initial, .new]) { _, change  in
            guard let newValue = change.newValue else {
                return
            }
            if #available(macOS 11, *) {
                configuration.defaultWebpagePreferences.allowsContentJavaScript = newValue
            } else if configuration.responds(to: #selector(setter: WKWebViewConfiguration._allowsJavaScriptMarkup)) {
                configuration._allowsJavaScriptMarkup = newValue
            }
        }

        // user scripts (user content controller)
        let contentController = configuration.userContentController
        contentController.removeAllUserScripts()

        let errorScript = WKUserScript(source: CustomWKWebView.errorScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(errorScript)

        let contextMenuScript = WKUserScript(source: CustomWKWebView.contextMenuScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(contextMenuScript)

        let linkHoverScript = WKUserScript(source: CustomWKWebView.linkHoverScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(linkHoverScript)

        // configuration
        // for useragent, we mimic the installed version of Safari and add our own identifier
        let shortSafariVersion = Bundle(path: "/Applications/Safari.app")?.infoDictionary?["CFBundleShortVersionString"] as? String
        let viennaVersion = (NSApp as? ViennaApp)?.applicationVersion
        configuration.applicationNameForUserAgent = "Version/\(shortSafariVersion ?? "9.1") Safari/605 Vienna/\(viennaVersion ?? "3.5+")"
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.all

        super.init(frame: frame, configuration: configuration)

        resetScriptListeners()

        self.allowsMagnification = true
        self.allowsBackForwardNavigationGestures = true
        self.allowsLinkPreview = true
        if #available(macOS 13.3, *) {
            isInspectable = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("initWithCoder not implemented for CustomWKWebView")
    }

    func resetScriptListeners() {
        let contentController = self.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: CustomWKWebView.clickListenerName)
        contentController.removeScriptMessageHandler(forName: CustomWKWebView.jsErrorListenerName)
        let contextMenuListener = CustomWKWebViewContextMenuListener()
        self.contextMenuListener = contextMenuListener
        contentController.add(contextMenuListener, name: CustomWKWebView.clickListenerName)
        contentController.add(CustomWKWebViewErrorListener(), name: CustomWKWebView.jsErrorListenerName)
        resetHoverUiListener()
    }

    func resetHoverUiListener() {
        let contentController = self.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: CustomWKWebView.mouseDidEnterName)
        contentController.removeScriptMessageHandler(forName: CustomWKWebView.mouseDidExitName)
        if let hoverUiDelegate = hoverUiDelegate {
            let hoverListener = CustomWKWebViewHoverListener(hoverDelegate: hoverUiDelegate)
            contentController.add(hoverListener, name: CustomWKWebView.mouseDidEnterName)
            contentController.add(hoverListener, name: CustomWKWebView.mouseDidExitName)
        }
    }

    func search(_ text: String = "", upward: Bool = false) {
        self.evaluateJavaScript("window.find(textToFind='\(text)', matchCase=false, searchUpward=\(upward ? "true" : "false"), wrapAround=true)", completionHandler: nil)
    }

    private func evaluateScrollPossibilities() -> (scrollDownPossible: Bool, scrollUpPossible: Bool) {

        // this is an idea adapted from Brent Simmons which he uses in NetNewsWire (https://github.com/brentsimmons/NetNewsWire)

        var scrollDownPossible = false
        var scrollUpPossible = false

        let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: window.scrollY}; x"

        waitForAsyncExecution(until: DispatchTime.now() + DispatchTimeInterval.milliseconds(200)) { finishHandler in
            self.evaluateJavaScript(javascriptString) { info, _ in

                guard let info = info as? [String: Any] else {
                    return
                }
                guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
                    return
                }

                let viewHeight = self.frame.height
                scrollDownPossible = viewHeight + offsetY < contentHeight
                scrollUpPossible = offsetY > 0.1

                finishHandler()
            }
        }

        return (scrollDownPossible, scrollUpPossible)
    }

    // disable scrolling of the webview if it is included in a NSScrollView
    // (https://stackoverflow.com/questions/43961952/disable-scrolling-of-wkwebview-in-nsscrollview)
    // (needed for correct scrolling in Unified layout)
    override func scrollWheel(with theEvent: NSEvent) {
        if self.enclosingScrollView != nil {
            nextResponder?.scrollWheel(with: theEvent)
        } else {
            super.scrollWheel(with: theEvent) // usual behavior of a WKWebView
        }
    }

    private func getTextSelection() -> String {
        var text = ""
        waitForAsyncExecution(until: DispatchTime.now() + DispatchTimeInterval.seconds(1)) { finishHandler in
            self.evaluateJavaScript("window.getSelection().getRangeAt(0).toString()") { res, _ in
                guard let selectedText = res as? String else {
                    return
                }
                text = selectedText
                finishHandler()
            }
        }
        return text
    }

    // MARK: Text zoom

    // swiftlint:disable:next private_action
    @IBAction func makeTextStandardSize(_ sender: Any?) {
        guard responds(to: #selector(getter: _supportsTextZoom)),
              responds(to: #selector(setter: _textZoomFactor)),
              _supportsTextZoom
        else {
            return
        }

        _textZoomFactor = 1.0
    }

    var canMakeTextLarger: Bool {
        guard responds(to: #selector(getter: _supportsTextZoom)),
              responds(to: #selector(getter: _textZoomFactor)),
              responds(to: #selector(setter: _textZoomFactor)),
              _supportsTextZoom
        else {
            return false
        }

        return Float(_textZoomFactor) < 3.0
    }

    var canMakeTextSmaller: Bool {
        guard responds(to: #selector(getter: _supportsTextZoom)),
              responds(to: #selector(getter: _textZoomFactor)),
              responds(to: #selector(setter: _textZoomFactor)),
              _supportsTextZoom
        else {
            return false
        }

        return Float(_textZoomFactor) > 0.5
    }

    // swiftlint:disable:next private_action
    @IBAction func makeTextLarger(_ sender: Any?) {
        guard canMakeTextLarger else {
            return
        }

        _textZoomFactor += 0.1
    }

    // swiftlint:disable:next private_action
    @IBAction func makeTextSmaller(_ sender: Any?) {
        guard canMakeTextSmaller else {
            return
        }

        _textZoomFactor -= 0.1
    }

    // MARK: Printing

    // WKWebView's own implementation does nothing.
    override func printView(_ sender: Any?) {
        guard let window else {
            return
        }

        let printOperation: NSPrintOperation
        if #available(macOS 11, *) {
            printOperation = self.printOperation(with: .shared)
        } else if responds(to: #selector(_printOperation(with:))) {
            printOperation = _printOperation(with: .shared)
        } else {
            return
        }

        // The default margins are too wide. This value is similar to Safari.
        let printInfo = printOperation.printInfo
        let margin = 18.0
        printInfo.topMargin = margin
        printInfo.leftMargin = margin
        printInfo.rightMargin = margin
        printInfo.bottomMargin = margin

        // These printing options are missing from the standard print panel.
        let options: NSPrintPanel.Options = [.showsPaperSize, .showsOrientation, .showsScaling]
        printOperation.printPanel.options.insert(options)

        // The view's frame has to be defined, otherwise program execution is
        // halted here. See: https://stackoverflow.com/a/69839912/6423906
        printOperation.view?.frame = bounds

        printOperation.canSpawnSeparateThread = true
        printOperation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }
}

// MARK: context menu
extension CustomWKWebView {

    // TODO: debugging js in WKWebView thanks to https://stackoverflow.com/a/61031417/3311272 .
    static let errorScriptSource = """
    window.onerror = (msg, url, line, column, error) => {
        const message = {
            message: msg,
            url: url,
            line: line,
            column: column,
            error: JSON.stringify(error)
        }

        if (window.webkit) {
            window.webkit.messageHandlers.\(jsErrorListenerName).postMessage(message);
        } else {
            console.log("Error:", message);
        }
    };
    """

    static let contextMenuScriptSource = """
    document.addEventListener('contextmenu', function(e) {
        var htmlElement = document.elementFromPoint(e.clientX, e.clientY);
        var link = htmlElement.closest("a");
        if (link) {
            var url = new URL(link.getAttribute('href'), document.baseURI).href;
            window.webkit.messageHandlers.\(clickListenerName).postMessage('link: ' + url);
        }
        var mediasource = htmlElement.currentSrc;
        if (mediasource) {
            var url = new URL(mediasource, document.baseURI).href;
            window.webkit.messageHandlers.\(clickListenerName).postMessage('media: ' + url);
        } else {
            var img = htmlElement.closest("img");
            if (img) {
                var url = new URL(img.getAttribute('src'), document.baseURI).href;
                window.webkit.messageHandlers.\(clickListenerName).postMessage('media: ' + url);
            } else {
                var userselection = window.getSelection();
                if (userselection.rangeCount > 0) {
                    window.webkit.messageHandlers.\(clickListenerName).postMessage('text: ' + userselection.getRangeAt(0).toString())
                }
            }
        }
    })
    """

    static let linkHoverScriptSource = """
    window.onmouseover = function(event) {
        var closestAnchor = event.target.closest('a')
        if (closestAnchor) {
            window.webkit.messageHandlers.\(mouseDidEnterName).postMessage(closestAnchor.href);
        }
    }
    window.onmouseout = function(event) {
        var closestAnchor = event.target.closest('a')
        if (closestAnchor) {
            window.webkit.messageHandlers.\(mouseDidExitName).postMessage(closestAnchor.href);
        }
    }
    """

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {

        super.willOpenMenu(menu, with: event)
        if contextMenuProvider != nil {
            customize(contextMenu: menu)
        }
    }

    private func customize(contextMenu menu: NSMenu) {

        guard let contextMenuProvider = contextMenuProvider,
              let contextMenuListener = contextMenuListener else {
            return
        }

        let clickedOnLink = menu.items.contains { $0.identifier == .WKMenuItemOpenLinkInNewWindow }
        let clickedOnMedia = menu.items.contains { $0.identifier == .WKMenuItemOpenMediaInNewWindow || $0.identifier == .WKMenuItemOpenImageInNewWindow }
        let clickedOnCopyableItem = menu.items.contains { $0.identifier == .WKMenuItemCopy }

        let context: WKWebViewContextMenuContext

        if clickedOnLink && clickedOnMedia {
            context = .mediaLink(
                media: contextMenuListener.lastRightClickedMediaSrc ?? URL.blank,
                link: contextMenuListener.lastRightClickedLink ?? URL.blank)
        } else if clickedOnLink {
            context = .link(contextMenuListener.lastRightClickedLink ?? URL.blank)
        } else if clickedOnMedia {
            context = .media(contextMenuListener.lastRightClickedMediaSrc ?? URL.blank)
        } else if clickedOnCopyableItem {
            context = .text(contextMenuListener.lastSelectedText ?? "")
        } else {
            context = .page(url: self.url ?? URL.blank)
        }

        menu.items = contextMenuProvider.contextMenuItemsFor(purpose: context, existingMenuItems: menu.items)

        contextMenuListener.lastRightClickedLink = nil
        contextMenuListener.lastRightClickedMediaSrc = nil
        contextMenuListener.lastSelectedText = nil
    }
}

class CustomWKWebViewHoverListener: NSObject, WKScriptMessageHandler {

    weak var hoverDelegate: CustomWKHoverUIDelegate?

    init(hoverDelegate: CustomWKHoverUIDelegate) {
        self.hoverDelegate = hoverDelegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let hoverDelegate = hoverDelegate else {
            return
        }
        if message.name == CustomWKWebView.mouseDidEnterName {
            if let link = message.body as? String {
                hoverDelegate.hovered(link: link)
            }
        } else if message.name == CustomWKWebView.mouseDidExitName {
            hoverDelegate.hovered(link: nil)
        }
    }
}

class CustomWKWebViewContextMenuListener: NSObject, WKScriptMessageHandler {

    var lastRightClickedLink: URL?
    var lastRightClickedMediaSrc: URL?
    var lastSelectedText: String?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let urlString = message.body as? String {
            if urlString.starts(with: "link: "), let url = URL(string: urlString.replacingOccurrences(of: "link: ", with: "", options: .anchored)) {
                self.lastRightClickedLink = url
            } else if urlString.starts(with: "media: "), let url = URL(string: urlString.replacingOccurrences(of: "media: ", with: "", options: .anchored)) {
                self.lastRightClickedMediaSrc = url
            } else if urlString.starts(with: "text: ") {
                lastSelectedText = urlString.replacingOccurrences(of: "text: ", with: "", options: .anchored)
            }
        }
    }
}

class CustomWKWebViewErrorListener: NSObject, WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message.body)
    }
}
