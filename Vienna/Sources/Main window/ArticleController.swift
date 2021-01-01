//
//  ArticleController.swift
//  Vienna
//
//  Created by Tassilo Karge on 25.04.19.
//  Copyright © 2019 uk.co.opencommunity. All rights reserved.
//

import Foundation

extension ArticleController: Tab {
	public var url: URL? {
		get {
			guard let selectedArticle = self.selectedArticle else { return nil }
			return urlFromUserString(selectedArticle.link)
		}
		set {}
	}

	public var textSelection: String {
		return ""
	}

	public var html: String {
		return ""
	}

	public var loading: Bool {
		return false
	}

	public func back() -> Bool {
		return self.canGoBack
	}

	public func forward() -> Bool {
		return self.canGoForward
	}

	public func pageDown() -> Bool {
		return false
	}

	public func pageUp() -> Bool {
		return false
	}

	public func searchFor(_ searchString: String, action: NSFindPanelAction) -> Bool {
		return false
	}

	public func load() {}

	public func reload() {}

	public func stopLoading() {}

	public func decreaseTextSize() {

	}

	public func increaseTextSize() {

	}

	public func print() {

	}

}
