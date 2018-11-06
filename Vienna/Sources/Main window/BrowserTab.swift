//
//  BrowserTab.swift
//  Vienna
//
//  Created by Tassilo Karge on 27.10.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

import Cocoa

@available(OSX 10.10, *)
class BrowserTab: NSViewController {

    @IBOutlet weak var addressField: NSTextField!
    var webView: WKWebView! = WKWebView()
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var forwardButton: NSButton!
    @IBOutlet weak var reloadButton: NSButton!

    var url: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(webView)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView]|", options: [], metrics: nil, views: ["webView" : webView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[addressField][webView]|", options: [], metrics: nil, views: ["webView" : webView, "addressField" : addressField]))
        //TODO: set webview options since this is not possible before macOS 12 more in IB
    }
}

@available(OSX 10.10, *)
extension BrowserTab: Tab {

    var textSelection: String {
        get {return ""}
    }

    var html: String {
        get {return ""}
    }

    var loading: Bool {
        get {return false}
    }

    func back() {

    }

    func forward() {

    }

    func pageDown() {

    }

    func pageUp() {

    }

    func searchFor(_ searchString: String, action: NSFindPanelAction) {

    }

    func load() {

    }

    func reload() {

    }

    func stopLoading() {

    }

    func close() {

    }

    func decreaseTextSize() {

    }

    func increaseTextSize() {

    }

    func print() {

    }
}
