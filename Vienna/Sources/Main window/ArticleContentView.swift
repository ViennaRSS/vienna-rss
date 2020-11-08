//
//  ArticleContentView.swift
//
//  Copyright 2019
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

@objc
protocol ArticleContentView {
	var htmlTemplate: String { get set }
	var cssStylesheet: String { get set }
	var jsScript: String { get set }
	var currentHTML: String { get set }

	func clearHTML()
	func setHTML(_ htmlText: String)
	func articleText(fromArray msgArray: [Any])
	func keyDown(_ theEvent: NSEvent)

	//from tabbedwebview
	//TODO: evaluate and throw out what is not necessary / duplicate from Tab
	func setOpenLinksInNewBrowser(_ flag: Bool)
	func printDocument(_ sender: Any)
	func abortJavascriptAndPlugIns()
	func useUserPrefsForJavascriptAndPlugIns()
	func forceJavascript()
	var feedRedirect: Bool { get }
	var download: Bool { get }
	func scrollToTop()
	func scrollToBottom()
}
