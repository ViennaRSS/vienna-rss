//
//  ArticleContentView.swift
//  Vienna
//
//  Copyright 2019
//

import Foundation

@objc
protocol ArticleContentView: Tab {

    var listView: ArticleViewDelegate? { get set }
    var html: String { get set }
	func clearHTML()

	@objc(keyDown:)
	func keyDown(with event: NSEvent)

	//from tabbedwebview
	//TODO: evaluate and throw out what is not necessary / replace with Tab interface
	func printDocument(_ sender: Any)
	func abortJavascriptAndPlugIns()
	func useUserPrefsForJavascriptAndPlugIns()
	func forceJavascript()

	func scrollToTop()
	func scrollToBottom()

	//other requirements (originally from WebView)
	//TODO: replace with Tab interface
	func makeTextSmaller(_ sender: Any)
	func makeTextLarger(_ sender: Any)
}
