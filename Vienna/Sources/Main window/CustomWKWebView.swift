//
//  CustomWKWebView.swift
//  Vienna
//
//  Copyright 2019
//

import Cocoa

@available(OSX 10.10, *)
public class CustomWKWebView: WKWebView {

    weak var contextMenuProvider: CustomWKUIDelegate?

    var canScrollDown: Bool {
        evaluateScrollPossibilities().scrollDownPossible
    }
    var canScrollUp: Bool {
        evaluateScrollPossibilities().scrollUpPossible
    }
    var textSelection: String {
        return getTextSelection()
    }

    private var lastRightClickedLink: URL?
    private var lastRightClickedImgSrc: URL?

    public override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {

        //preferences
        let prefs = configuration.preferences
        prefs.javaScriptEnabled = true
        prefs.javaScriptCanOpenWindowsAutomatically = true
        prefs.plugInsEnabled = true

        //user scripts (user content controller)
        let contentController = configuration.userContentController
        contentController.removeAllUserScripts()

        let errorScript = WKUserScript(source: CustomWKWebView.errorScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(errorScript)

        let contextMenuScript = WKUserScript(source: CustomWKWebView.contextMenuScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(contextMenuScript)

        //configuration
        if #available(OSX 10.11, *) {
            // for useragent, we mimic the installed version of Safari and add our own identifier
            let shortSafariVersion = Bundle(path: "/Applications/Safari.app")?.infoDictionary?["CFBundleShortVersionString"] as? String
            let viennaVersion = (NSApp as? ViennaApp)?.applicationVersion?.prefix(while: { character in character != " " })
            configuration.applicationNameForUserAgent = "Version/\(shortSafariVersion ?? "9.1") Safari/605 Vienna/\(viennaVersion ?? "3.5+")"
            configuration.allowsAirPlayForMediaPlayback = true
        }
        if #available(OSX 10.12, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.all
        }

        super.init(frame: frame, configuration: configuration)

        contentController.removeScriptMessageHandler(forName: "clickListener")
        contentController.add(self, name: "clickListener")

        self.allowsMagnification = true
        self.allowsBackForwardNavigationGestures = true
        if #available(OSX 10.11, *) {
            self.allowsLinkPreview = true
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("initWithCoder not implemented for CustomWKWebView")
    }

    public func search(_ text: String = "", upward: Bool = false) {
        self.evaluateJavaScript("window.find(textToFind='\(text)', matchCase=false, searchUpward=\(upward ? "true" : "false"), wrapAround=true)", completionHandler: nil)
    }

    private func evaluateScrollPossibilities() -> (scrollDownPossible: Bool, scrollUpPossible: Bool) {

        //this is an idea adapted from Brent Simmons which he uses in NetNewsWire (https://github.com/brentsimmons/NetNewsWire)

        var scrollDownPossible = false
        var scrollUpPossible = false

        let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: document.body.scrollTop}; x"

        waitForAsyncExecution(until: DispatchTime.now() + DispatchTimeInterval.seconds(1)) { finishHandler in
            self.evaluateJavaScript(javascriptString) { info, error in

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
extension CustomWKWebView: WKScriptMessageHandler {

    //TODO: debugging js in WKWebView thanks to https://stackoverflow.com/a/61031417/3311272 . Remove for production.
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
            window.webkit.messageHandlers.clickListener.postMessage(message);
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
                window.webkit.messageHandlers.clickListener.postMessage('link: ' + url);
            } else if (tagName === 'IMG' && img == undefined) {
                img = htmlElement;
                var url = new URL(img.getAttribute('src'), document.baseURI).href;
                window.webkit.messageHandlers.clickListener.postMessage('img: ' + url);
            }
        }
    })
    """

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message.body) //TODO: remove for production
        if let urlString = message.body as? String {
            if urlString.starts(with: "link: "), let url = URL(string: urlString.replacingOccurrences(of: "link: ", with: "", options: .anchored)) {
                self.lastRightClickedLink = url
            } else if urlString.starts(with: "img: "), let url = URL(string: urlString.replacingOccurrences(of: "img: ", with: "", options: .anchored)) {
                self.lastRightClickedImgSrc = url
            }
        }
    }

    open override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {

        if contextMenuProvider != nil {
            customize(contextMenu: menu)
        }
        super.willOpenMenu(menu, with: event)
    }

    private func customize(contextMenu menu: NSMenu) {

        let clickedOnLink = menu.items.contains { $0.identifier?.rawValue == "WKMenuItemIdentifierOpenLinkInNewWindow" }
        let clickedOnImage = menu.items.contains { $0.identifier?.rawValue == "WKMenuItemIdentifierOpenLinkInNewWindow" }
        let clickedOnText = menu.items.contains { $0.identifier?.rawValue == "WKMenuItemIdentifierCopy" }

        let context: WKWebViewContextMenuContext
        let blankUrl = URL(string: "about:blank")!

        if clickedOnLink && clickedOnImage {
            context = .pictureLink(image: self.lastRightClickedImgSrc ?? blankUrl, link: self.lastRightClickedLink ?? blankUrl)
        } else if clickedOnLink {
            context = .link(self.lastRightClickedLink ?? blankUrl)
        } else if clickedOnImage {
            context = .picture(self.lastRightClickedImgSrc ?? blankUrl)
        } else if clickedOnText {
            context = .text(getTextSelection())
        } else {
            context = .page(url: self.url ?? blankUrl)
        }

        menu.items = contextMenuProvider?.contextMenuItemsFor(purpose: context, existingMenuItems: menu.items) ?? menu.items
        lastRightClickedLink = nil
    }
}
