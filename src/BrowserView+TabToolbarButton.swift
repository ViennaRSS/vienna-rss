//
//  BrowserView+TabToolbarButton.swift
//  Vienna
//
//  Created by Tassilo Karge on 15.04.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

import Foundation

@available(OSX 10.10, *)
extension BrowserView {

    private func getTabToolbarButton() -> NSTitlebarAccessoryViewController {
        if self.addTabToolbarButton == nil {
            self.addTabToolbarButton = NSTitlebarAccessoryViewController(nibName: NSNib.Name("AddTabToolbarButton"), bundle: nil)
            getTabToolbarButton().layoutAttribute = .right
        }
        return self.addTabToolbarButton as! NSTitlebarAccessoryViewController
    }

    @objc func showAddTabButtonInToolbar() {
        let window = NSApplication.shared.windows[0]
        guard let toolbar = window.toolbar
            else {return}
        if !window.titlebarAccessoryViewControllers.contains(getTabToolbarButton()) {
            window.addTitlebarAccessoryViewController(getTabToolbarButton())
            let behindLastIndex = toolbar.items.count
            window.toolbar?.insertItem(withItemIdentifier: NSToolbarItem.Identifier.space, at:behindLastIndex)
        }
    }

    @objc func removeAddTabButtonFromToolbar() {
        let window = NSApplication.shared.windows[0]
        guard let toolbar = window.toolbar,
            let buttonIndex = window.titlebarAccessoryViewControllers.index(of: getTabToolbarButton())
            else {return}
        window.removeTitlebarAccessoryViewController(at: buttonIndex)
        if let lastIdentifier = toolbar.items.last?.itemIdentifier, lastIdentifier == NSToolbarItem.Identifier.space {
            toolbar.removeItem(at: toolbar.items.count - 1)
        }
    }
}
