//
//  WebKitArticleView.swift
//  Vienna
//
//  Copyright 2019
//

import Foundation

@available(OSX 10.10, *)
@objc
class WebKitArticleView: CustomWKWebView, ArticleContentView {

	// MARK: Tab

	var tabUrl: URL?

	override var textSelection: String { "" } //TODO

	var html: String = "" //TODO

	func back() -> Bool {
		//TODO
		return false
	}

	func forward() -> Bool {
		//TODO
		return false
	}

	func pageDown() -> Bool {
		let canScrollDown = self.canScrollDown
		scrollPageDown(self)
		return canScrollDown
	}

	func pageUp() -> Bool {
		let canScrollUp = self.canScrollUp
		scrollPageUp(self)
		return canScrollUp
	}

	func searchFor(_ searchString: String, action: NSFindPanelAction) {
        search(searchString, upward: action == NSFindPanelAction.previous)
	}

	func loadTab() {
        if let url = tabUrl {
            self.load(URLRequest(url: url))
        } else {
            let blankUrl = URL(string: "about:blank")!
            self.load(URLRequest(url: blankUrl))
        }
	}

	func reloadTab() {
        self.reload()
	}

	func stopLoadingTab() {
		//TODO
	}

	func decreaseTextSize() {
		//TODO
	}

	func increaseTextSize() {
		//TODO
	}

	func printPage() {
		//TODO
	}

	// MARK: ArticleContentView remainder

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

    var listView: ArticleViewDelegate?

	var htmlTemplate: String = "" //TODO

	var cssStylesheet: String = "" //TODO

	var jsScript: String = "" //TODO

	var currentHTML: String = "" //TODO

	func clearHTML() {
		//TODO
	}

	func setHTML(_ htmlText: String) {
		//TODO
	}

	func articleText(fromArray msgArray: [Any]) {
		//TODO
	}

	func setOpenLinksInNewBrowser(_ flag: Bool) {
		//TODO
	}

	func printDocument(_ sender: Any) {
		//TODO
	}

	func abortJavascriptAndPlugIns() {
		//TODO
	}

	func useUserPrefsForJavascriptAndPlugIns() {
		//TODO
	}

	func forceJavascript() {
		//TODO
	}

	var feedRedirect: Bool

	var download: Bool

	func scrollToTop() {
		//TODO
	}

	func scrollToBottom() {
		//TODO
	}

	@objc(keyDown:)
	override func keyDown(with event: NSEvent) {
		//TODO
	}

	func makeTextSmaller(_ sender: Any) {
		//TODO
	}

	func makeTextLarger(_ sender: Any) {
		//TODO
	}

    func activateAddressBar() {
        //there is no address bar in articleView
    }
}
