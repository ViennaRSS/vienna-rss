//
//  CustomWKWebView.swift
//  Vienna
//
//  Copyright 2019
//

import Cocoa

@available(OSX 10.10, *)
class CustomWKWebView: WKWebView {
	var canScrollDown: Bool {
		evaluateScrollPossibilities()
		return scrollDownPossible
	}
	var canScrollUp: Bool {
		evaluateScrollPossibilities()
		return scrollUpPossible
	}

	let synchronizationGroup = DispatchGroup()

	private var scrollDownPossible = false
	private var scrollUpPossible = false

	private func evaluateScrollPossibilities() {

		//this is an idea adapted from Brent Simmons which he uses in NetNewsWire (https://github.com/brentsimmons/NetNewsWire)

		let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: document.body.scrollTop}; x"

		let evaluation = { (info: Any?, error: Error?) in
			guard let info = info as? [String: Any] else {
				self.scrollDownPossible = false
				self.scrollUpPossible = false
				return
			}
			guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
				self.scrollDownPossible = false
				self.scrollUpPossible = false
				return
			}

			let viewHeight = self.frame.height
			self.scrollDownPossible = viewHeight + offsetY < contentHeight
			self.scrollUpPossible = offsetY > 0.1 }

		synchronizationGroup.enter()
		self.evaluateJavaScript(javascriptString) { info, error in
			evaluation(info, error)
			self.synchronizationGroup.leave()
		}

		synchronizationGroup.wait()
	}
}
