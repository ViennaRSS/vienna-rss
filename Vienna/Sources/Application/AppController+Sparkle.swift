//
//  AppController+Sparkle.swift
//  Vienna
//
//  Copyright 2020
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
import Sparkle

extension AppController: SUUpdaterDelegate {

	public func feedURLString(for updater: SUUpdater) -> String? {
		guard var urlString = Bundle.main.infoDictionary?["SUFeedURL"] as? String else {
			return nil
		}

		if Preferences.standard()?.alwaysAcceptBetas == true {
			guard let referenceURL = URL(string: urlString) else {
				print("Invalid Sparkle feed URL : \(urlString)")
				return nil
			}

			let pathExt = referenceURL.pathExtension
			let pathURL = referenceURL.deletingLastPathComponent()
			let newURL = pathURL.appendingPathComponent("changelog_beta").appendingPathExtension(pathExt)
			urlString = newURL.absoluteString
		}

		return urlString
	}

	public func updaterWillRelaunchApplication(_ updater: SUUpdater) {
		Preferences.standard()?.handleUpdateRestart()
	}

}
