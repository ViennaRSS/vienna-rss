//
//  ArticleController.swift
//  Vienna
//
//  Copyright 2019
//

import Foundation

extension ArticleController: Tab {

	public var tabUrl: URL? {
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

	public var isLoading: Bool {
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

	public func searchFor(_ searchString: String, action: NSFindPanelAction) {
        //TODO
    }

	public func loadTab() {}

	public func reloadTab() {}

	public func stopLoadingTab() {}

	public func decreaseTextSize() {

	}

	public func increaseTextSize() {

	}

	public func print() {

	}
    
    public func activateAddressBar() {
        //there is no address bar in the articlecontroller
    }

}
