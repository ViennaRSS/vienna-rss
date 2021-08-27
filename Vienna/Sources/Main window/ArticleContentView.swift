//
//  ArticleContentView.swift
//  Vienna
//
//  Copyright 2019
//

import Foundation

@objc
protocol ArticleContentView {

    var listView: ArticleViewDelegate? { get set }
    var articles: [Article] { get set }

    @objc(keyDown:)
    func keyDown(with event: NSEvent)

    // MARK: visual settings

    func decreaseTextSize()
    func increaseTextSize()

}
