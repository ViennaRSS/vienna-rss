//
//  TabOrderPreferencesViewController.swift
//  Vienna
//
//  Created by Tassilo Karge on 11.10.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

import Cocoa

class TabOrderPreferencesViewController: NSViewController, MASPreferencesViewController {
    var viewIdentifier: String = ""

    var toolbarItemLabel: String?


    @available(OSX 10.10, *)
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override func viewWillAppear() {
        if #available(OSX 10.10, *) {
            super.viewWillAppear()
        }

        self.initializePreferences()
    }

    override func viewDidDisappear() {
        if #available(OSX 10.10, *) {
            super.viewDidDisappear()
        }
    }


    func initializePreferences() {
        let prefs = Preferences.standard()
    }
}
