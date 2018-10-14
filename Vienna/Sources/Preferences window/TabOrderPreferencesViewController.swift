//
//  TabOrderPreferencesViewController.swift
//  Vienna
//
//  Created by Tassilo Karge on 11.10.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

import Cocoa

class TabOrderPreferencesViewController: NSViewController, MASPreferencesViewController {

    @IBOutlet weak var openLastReadTabButton: NSButton!
    @IBOutlet weak var openNewTabFirstButton: NSButton!
    @IBOutlet weak var lastReadCanJumpToArticlesButton: NSButton!
    @IBOutlet weak var noLastReadOpenLeftButton: NSButtonCell!
    @IBOutlet weak var noLastReadOpenRightButton: NSButton!
    @IBOutlet weak var openLeftTabButton: NSButton!
    @IBOutlet weak var openLeftCanJumpToArticlesButton: NSButton!
    @IBOutlet weak var openRightTabButton: NSButton!

    //MASPreferencesViewController

    var viewIdentifier: String = "TabOrderPreferences"
    var toolbarItemLabel: String? = NSLocalizedString("Tab reading order", comment: "Toolbar item name for the Tab reading order preference pane")


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

    //Vienna preferences

    func initializePreferences() {
        let prefs = Preferences.standard()

        let openLastRead = prefs.selectPreviousOnClose
        let openRight = prefs.selectRightItemFirst
        let canOpenArticles = prefs.canJumpToArticles

        openLastReadTabButton.state = openLastRead ? .on : .off
        openNewTabFirstButton.isEnabled = openLastRead
        lastReadCanJumpToArticlesButton.isEnabled = openLastRead
        noLastReadOpenRightButton.isEnabled = openLastRead
        noLastReadOpenLeftButton.isEnabled = openLastRead

        openLeftTabButton.state = !openLastRead && !openRight ? .on : .off
        openLeftCanJumpToArticlesButton.isEnabled = !(openLastRead || openRight)

        noLastReadOpenLeftButton.state = !openRight ? .on : .off

        openRightTabButton.state = !openLastRead && openRight ? .on : .off

        noLastReadOpenRightButton.state = openRight ? .on : .off

        lastReadCanJumpToArticlesButton.state = canOpenArticles ? .on : .off
        openLeftCanJumpToArticlesButton.state = canOpenArticles ? .on : .off
    }

    @IBAction func openLastReadTab(_ sender: NSButton) {
        Preferences.standard().selectPreviousOnClose = (sender.state == .on)
        initializePreferences()
    }

    @IBAction func openNewTabFirst(_ sender: NSButton) {
        Preferences.standard().selectNewItemFirst = (sender.state == .on)
        initializePreferences()
    }

    @IBAction func openLeftTab(_ sender: NSButton) {
        Preferences.standard().selectRightItemFirst = (sender.state == .off)
        //TODO: find out if cocoa has something like button group, to avoid this ugly pattern
        if sender == openLeftTabButton && sender.state == .on {
            Preferences.standard().selectPreviousOnClose = false
        }
        initializePreferences()
    }

    @IBAction func openRightTab(_ sender: NSButton) {
        Preferences.standard().selectRightItemFirst = (sender.state == .on)
        //TODO: find out if cocoa has something like button group, to avoid this ugly pattern
        if sender == openRightTabButton && sender.state == .on {
            Preferences.standard().selectPreviousOnClose = false
        }
        initializePreferences()
    }

    @IBAction func canJumpToArticles(_ sender: NSButton) {
        Preferences.standard().canJumpToArticles = (sender.state == .on)
        initializePreferences()
    }

}
