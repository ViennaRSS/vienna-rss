//
//  CustomWKWebView.swift
//  Vienna
//
//  Copyright 2019
//

import Cocoa

@available(OSX 10.10, *)
public class CustomWKWebView: WKWebView, WKScriptMessageHandler {

    public weak var contextMenuProvider: CustomWKUIDelegate?

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

    public override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {

        //preferences
        let prefs = configuration.preferences
        prefs.javaScriptEnabled = true
        prefs.javaScriptCanOpenWindowsAutomatically = true
        prefs.plugInsEnabled = true

        //user scripts (user content controller)
        let contentController = configuration.userContentController
        contentController.removeAllUserScripts()

        let scriptSource = "document.addEventListener('contextmenu', function(e) { window.webkit.messageHandlers.clickListener.postMessage(e.target.toString()); })"
        //if($(e.target).is('a')) { window.webkit.messageHandlers.contextMenuListener.postMessage( e.target.attr('href') ) }
        //window.location.protocol + "//" + window.location.host + "/" + e.target.attr('href')
        let rightClickListenerScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(rightClickListenerScript)

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

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message.body) //TODO: remove for production
        if let urlString = message.body as? String, let url = URL(string: urlString) {
            self.lastRightClickedLink = url
        }
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
extension CustomWKWebView {

    open override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {

        if contextMenuProvider != nil {
            customize(contextMenu: menu)
        }
        super.willOpenMenu(menu, with: event)
    }

    private func customize(contextMenu menu: NSMenu) {
        let context: WKWebViewContextMenuContext
        if menu.items.contains(where: { $0.identifier?.rawValue == "WKMenuItemIdentifierOpenLinkInNewWindow" }) {
            context = .link(url: self.lastRightClickedLink ?? URL(string: "about:blank")!)
        } else {
            context = .page(url: self.url ?? URL(string: "about:blank")!)
        }

        menu.items = contextMenuProvider?.contextMenuItemsFor(purpose: context, existingMenuItems: menu.items) ?? menu.items
    }
}

extension NSUserInterfaceItemIdentifier {
    static let WKMenuItemIdentifierOpenLinkInBackground = NSUserInterfaceItemIdentifier("WKMenuItemIdentifierOpenLinkInBackground")
    static let WKMenuItemIdentifierOpenLinkInSystemBrowser = NSUserInterfaceItemIdentifier("WKMenuItemIdentifierOpenLinkInSystemBrowser")
}
