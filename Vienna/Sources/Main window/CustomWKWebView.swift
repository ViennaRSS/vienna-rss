//
//  CustomWKWebView.swift
//  Vienna
//
//  Copyright 2019
//

import Cocoa

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

    @objc weak var hoverListener: WKScriptMessageHandler? {
        didSet {
            let contentController = self.configuration.userContentController
            contentController.removeScriptMessageHandler(forName: CustomWKWebView.mouseDidEnterName)
            contentController.removeScriptMessageHandler(forName: CustomWKWebView.mouseDidExitName)
            if let hoverListener = hoverListener {
                contentController.add(hoverListener, name: CustomWKWebView.mouseDidEnterName)
                contentController.add(hoverListener, name: CustomWKWebView.mouseDidExitName)
            }
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

    private var useJavaScriptObservation : NSKeyValueObservation?
    private var useWebPluginsObservation : NSKeyValueObservation?

    override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {

        // preferences
        let prefs = configuration.preferences
        prefs.javaScriptCanOpenWindowsAutomatically = true
        prefs._fullScreenEnabled = true

        #if DEBUG
        prefs._developerExtrasEnabled = true
        #endif

        useJavaScriptObservation = Preferences.standard.observe(\.useJavaScript, options: [.initial, .new]) { _, change  in
            guard let newValue = change.newValue else {
                return
            }
            if #available(macOS 11, *) {
                configuration.defaultWebpagePreferences.allowsContentJavaScript = newValue
            } else {
                 configuration._allowsJavaScriptMarkup = newValue
            }
        }

        useWebPluginsObservation = Preferences.standard.observe(\.useWebPlugins, options: [.initial, .new]) { _, change  in
            guard let newValue = change.newValue else {
                return
            }
            if #available(macOS 11, *) {
                // TODO: remove the plugins preference once minimal requirement is macOS 11
                // because plugins are deprecated and unsupported
            } else {
                prefs.plugInsEnabled = newValue
                prefs.javaEnabled = newValue
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
        if #available(OSX 10.11, *) {
            // for useragent, we mimic the installed version of Safari and add our own identifier
            let shortSafariVersion = Bundle(path: "/Applications/Safari.app")?.infoDictionary?["CFBundleShortVersionString"] as? String
            let viennaVersion = (NSApp as? ViennaApp)?.applicationVersion
            configuration.applicationNameForUserAgent = "Version/\(shortSafariVersion ?? "9.1") Safari/605 Vienna/\(viennaVersion ?? "3.5+")"
            configuration.allowsAirPlayForMediaPlayback = true
        }
        if #available(OSX 10.12, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.all
        }

        super.init(frame: frame, configuration: configuration)

        resetScriptListeners()

        self.allowsMagnification = true
        self.allowsBackForwardNavigationGestures = true
        if #available(OSX 10.11, *) {
            self.allowsLinkPreview = true
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
    }

    func search(_ text: String = "", upward: Bool = false) {
        self.evaluateJavaScript("window.find(textToFind='\(text)', matchCase=false, searchUpward=\(upward ? "true" : "false"), wrapAround=true)", completionHandler: nil)
    }

    private func evaluateScrollPossibilities() -> (scrollDownPossible: Bool, scrollUpPossible: Bool) {

        // this is an idea adapted from Brent Simmons which he uses in NetNewsWire (https://github.com/brentsimmons/NetNewsWire)

        var scrollDownPossible = false
        var scrollUpPossible = false

        let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: window.scrollY}; x"

        waitForAsyncExecution(until: DispatchTime.now() + DispatchTimeInterval.seconds(1)) { finishHandler in
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
        //TODO: this works only starting with webkit version used in Safari 12
        var elements = document.elementsFromPoint(e.clientX, e.clientY);
        var link;
        var img;
        for(var element in elements) { //search first link and first image
            var htmlElement = elements[element];
            var tagName = htmlElement.tagName;
            if (tagName === 'A' && link == undefined) {
                link = htmlElement;
                var url = new URL(link.getAttribute('href'), document.baseURI).href;
                window.webkit.messageHandlers.\(clickListenerName).postMessage('link: ' + url);
            } else if (tagName === 'IMG' && img == undefined) {
                img = htmlElement;
                var url = new URL(img.getAttribute('src'), document.baseURI).href;
                window.webkit.messageHandlers.\(clickListenerName).postMessage('img: ' + url);
            }
            var userselection = window.getSelection();
            if (userselection.rangeCount > 0) {
                window.webkit.messageHandlers.\(clickListenerName).postMessage('text: ' + userselection.getRangeAt(0).toString())
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

        if contextMenuProvider != nil {
            customize(contextMenu: menu)
        }
        super.willOpenMenu(menu, with: event)
    }

    private func customize(contextMenu menu: NSMenu) {

        guard let contextMenuProvider = contextMenuProvider,
              let contextMenuListener = contextMenuListener else {
            return
        }

        let clickedOnLink = menu.items.contains { $0.identifier == .WKMenuItemOpenLinkInNewWindow }
        let clickedOnImage = menu.items.contains { $0.identifier == .WKMenuItemOpenMediaInNewWindow || $0.identifier == .WKMenuItemOpenImageInNewWindow }
        let clickedOnText = menu.items.contains { $0.identifier == .WKMenuItemCopy }

        let context: WKWebViewContextMenuContext

        if clickedOnLink && clickedOnImage {
            context = .pictureLink(
                image: contextMenuListener.lastRightClickedImgSrc ?? URL.blank,
                link: contextMenuListener.lastRightClickedLink ?? URL.blank)
        } else if clickedOnLink {
            context = .link(contextMenuListener.lastRightClickedLink ?? URL.blank)
        } else if clickedOnImage {
            context = .picture(contextMenuListener.lastRightClickedImgSrc ?? URL.blank)
        } else if clickedOnText {
            context = .text(contextMenuListener.lastSelectedText ?? "")
        } else {
            context = .page(url: self.url ?? URL.blank)
        }

        menu.items = contextMenuProvider.contextMenuItemsFor(purpose: context, existingMenuItems: menu.items)

        contextMenuListener.lastRightClickedLink = nil
        contextMenuListener.lastRightClickedImgSrc = nil
        contextMenuListener.lastSelectedText = nil
    }
}

class CustomWKWebViewContextMenuListener: NSObject, WKScriptMessageHandler {

    var lastRightClickedLink: URL?
    var lastRightClickedImgSrc: URL?
    var lastSelectedText: String?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let urlString = message.body as? String {
            if urlString.starts(with: "link: "), let url = URL(string: urlString.replacingOccurrences(of: "link: ", with: "", options: .anchored)) {
                self.lastRightClickedLink = url
            } else if urlString.starts(with: "img: "), let url = URL(string: urlString.replacingOccurrences(of: "img: ", with: "", options: .anchored)) {
                self.lastRightClickedImgSrc = url
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
