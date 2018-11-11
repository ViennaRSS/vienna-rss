//
//  TitleChangingTabViewItem.swift
//  Vienna
//
//  Created by Tassilo Karge on 11.11.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//
// Swift version of https://github.com/thomasguenzel/blog/blob/master/NSTabViewItem_Title/GNTabViewItem.m
//

import Cocoa

@available(OSX 10.10, *)
class TitleChangingTabViewItem: NSTabViewItem {
    override var viewController: NSViewController? {
        didSet {
            super.viewController = viewController
            oldValue?.removeObserver(self, forKeyPath: "title")
            self.viewController?.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let object = object as? NSViewController, let viewController = viewController,
            keyPath == "title" && object == viewController {
            self.label = viewController.title ?? ""
        }
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
}
