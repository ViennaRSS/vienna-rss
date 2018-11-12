//
//  Tab.swift
//  Vienna
//
//  Created by Tassilo Karge on 31.10.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

import Foundation

@objc
protocol Tab {

    var url : URL? {get set}
    var title : String? {get}
    var textSelection : String {get}
    var html : String {get}
    var loading : Bool {get}

    //MARK: navigating

    func back()
    func forward()
    func pageDown()
    func pageUp()
    func searchFor(_ searchString: String, action: NSFindPanelAction)

    //MARK: tab life cycle

    func load()
    func reload()
    func stopLoading()

    //MARK: visual settings

    func decreaseTextSize()
    func increaseTextSize()

    //MARK: other actions

    func print()
}
