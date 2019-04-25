//
//  ArticleContentView.swift
//  Vienna
//
//  Copyright 2019
//

import Foundation

@objc
protocol ArticleContentView: Tab {
	var htmlTemplate: String { get set }
	var cssStylesheet: String { get set }
	var jsScript: String { get set }
	var currentHTML: String { get set }

	func clearHTML()
	func setHTML(_ htmlText: String)
	func articleText(fromArray msgArray: [Any])
	@objc(keyDown:)
	func keyDown(with event: NSEvent)

	//from tabbedwebview
	//TODO: evaluate and throw out what is not necessary / replace with Tab interface
	func setOpenLinksInNewBrowser(_ flag: Bool)
	func printDocument(_ sender: Any)
	func abortJavascriptAndPlugIns()
	func useUserPrefsForJavascriptAndPlugIns()
	func forceJavascript()

	var feedRedirect: Bool { get }
	var download: Bool { get }

	func scrollToTop()
	func scrollToBottom()

	//other requirements (originally from WebView)
	//TODO: replace with Tab interface
	func makeTextSmaller(_ sender: Any)
	func makeTextLarger(_ sender: Any)
}
